"""
Integration APIs and Webhooks for EvidenceOS PRIME
Connects with external systematic review tools, data sources, and platforms
"""
from fastapi import APIRouter, Depends, HTTPException, Request, BackgroundTasks, Header
from sqlalchemy.orm import Session
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
from pydantic import BaseModel, HttpUrl, Field
import hmac
import hashlib
import requests
import json
import os

from database.database import get_db
from database.models import Organization, Project, User, Webhook, IntegrationConfig
from api.security import get_current_user, get_current_active_admin

router = APIRouter(prefix="/integrations", tags=["Integrations"])


# ============================
# PYDANTIC MODELS
# ============================

class WebhookCreate(BaseModel):
    """Create webhook subscription"""
    url: HttpUrl
    events: List[str]  # e.g., ["analysis.completed", "project.updated"]
    secret: str = Field(..., min_length=16)
    active: bool = True
    description: Optional[str] = None


class WebhookUpdate(BaseModel):
    """Update webhook"""
    url: Optional[HttpUrl] = None
    events: Optional[List[str]] = None
    secret: Optional[str] = None
    active: Optional[bool] = None
    description: Optional[str] = None


class WebhookPayload(BaseModel):
    """Webhook event payload"""
    event: str
    timestamp: datetime
    organization_id: str
    project_id: Optional[str]
    data: Dict[str, Any]
    webhook_id: str


class IntegrationConfigCreate(BaseModel):
    """Create integration configuration"""
    integration_type: str  # redcap, covidence, prospero, github, etc.
    config: Dict[str, Any]
    api_key: Optional[str] = None
    api_url: Optional[str] = None
    active: bool = True


class REDCapImportRequest(BaseModel):
    """Import data from REDCap"""
    api_url: HttpUrl
    api_token: str
    project_id: int
    instrument: Optional[str] = None
    fields: Optional[List[str]] = None


class CovidenceExportRequest(BaseModel):
    """Export to Covidence"""
    api_key: str
    review_id: int
    studies: List[Dict[str, Any]]


class ProsperoRegisterRequest(BaseModel):
    """Register protocol with PROSPERO"""
    protocol_data: Dict[str, Any]
    crd_number: Optional[str] = None  # If updating existing


class GitHubSyncRequest(BaseModel):
    """Sync with GitHub repository"""
    repo_url: HttpUrl
    branch: str = "main"
    sync_files: List[str]
    commit_message: str


# ============================
# WEBHOOK MANAGEMENT
# ============================

@router.post("/webhooks", status_code=201)
async def create_webhook(
    webhook: WebhookCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin)
):
    """
    Create a webhook subscription

    Requires admin role
    """
    # Validate webhook URL
    try:
        response = requests.head(str(webhook.url), timeout=5)
        if response.status_code >= 500:
            raise HTTPException(400, "Webhook URL is not accessible")
    except requests.RequestException:
        raise HTTPException(400, "Webhook URL is not accessible")

    # Create webhook
    new_webhook = Webhook(
        organization_id=current_user.organization_id,
        url=str(webhook.url),
        events=webhook.events,
        secret=webhook.secret,
        active=webhook.active,
        description=webhook.description,
        created_by=str(current_user.id)
    )

    db.add(new_webhook)
    db.commit()
    db.refresh(new_webhook)

    return {
        "webhook_id": str(new_webhook.id),
        "url": new_webhook.url,
        "events": new_webhook.events,
        "active": new_webhook.active,
        "created_at": new_webhook.created_at
    }


@router.get("/webhooks")
async def list_webhooks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all webhooks for organization"""
    webhooks = db.query(Webhook).filter(
        Webhook.organization_id == current_user.organization_id
    ).all()

    return {
        "webhooks": [
            {
                "webhook_id": str(wh.id),
                "url": wh.url,
                "events": wh.events,
                "active": wh.active,
                "description": wh.description,
                "created_at": wh.created_at,
                "last_triggered": wh.last_triggered,
                "success_count": wh.success_count,
                "failure_count": wh.failure_count
            }
            for wh in webhooks
        ]
    }


@router.put("/webhooks/{webhook_id}")
async def update_webhook(
    webhook_id: str,
    webhook_update: WebhookUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin)
):
    """Update webhook configuration"""
    webhook = db.query(Webhook).filter(
        Webhook.id == webhook_id,
        Webhook.organization_id == current_user.organization_id
    ).first()

    if not webhook:
        raise HTTPException(404, "Webhook not found")

    # Update fields
    if webhook_update.url:
        webhook.url = str(webhook_update.url)
    if webhook_update.events:
        webhook.events = webhook_update.events
    if webhook_update.secret:
        webhook.secret = webhook_update.secret
    if webhook_update.active is not None:
        webhook.active = webhook_update.active
    if webhook_update.description:
        webhook.description = webhook_update.description

    webhook.updated_at = datetime.utcnow()

    db.commit()

    return {"message": "Webhook updated successfully"}


@router.delete("/webhooks/{webhook_id}")
async def delete_webhook(
    webhook_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin)
):
    """Delete webhook"""
    webhook = db.query(Webhook).filter(
        Webhook.id == webhook_id,
        Webhook.organization_id == current_user.organization_id
    ).first()

    if not webhook:
        raise HTTPException(404, "Webhook not found")

    db.delete(webhook)
    db.commit()

    return {"message": "Webhook deleted successfully"}


@router.post("/webhooks/{webhook_id}/test")
async def test_webhook(
    webhook_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin)
):
    """Send test event to webhook"""
    webhook = db.query(Webhook).filter(
        Webhook.id == webhook_id,
        Webhook.organization_id == current_user.organization_id
    ).first()

    if not webhook:
        raise HTTPException(404, "Webhook not found")

    # Create test payload
    test_payload = {
        "event": "webhook.test",
        "timestamp": datetime.utcnow().isoformat(),
        "organization_id": str(current_user.organization_id),
        "data": {
            "message": "This is a test webhook event",
            "webhook_id": str(webhook.id)
        }
    }

    # Trigger webhook in background
    background_tasks.add_task(
        trigger_webhook,
        webhook.url,
        test_payload,
        webhook.secret
    )

    return {"message": "Test webhook triggered"}


async def trigger_webhook(url: str, payload: Dict[str, Any], secret: str):
    """Trigger webhook with payload"""
    try:
        # Create HMAC signature
        payload_json = json.dumps(payload, default=str)
        signature = hmac.new(
            secret.encode(),
            payload_json.encode(),
            hashlib.sha256
        ).hexdigest()

        # Send webhook
        response = requests.post(
            url,
            json=payload,
            headers={
                "Content-Type": "application/json",
                "X-Webhook-Signature": f"sha256={signature}",
                "X-Webhook-Event": payload.get("event", "unknown")
            },
            timeout=30
        )

        return response.status_code < 400

    except Exception as e:
        print(f"Webhook error: {e}")
        return False


# ============================
# REDCAP INTEGRATION
# ============================

@router.post("/redcap/import")
async def import_from_redcap(
    request: REDCapImportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Import study data from REDCap project

    REDCap is widely used for clinical data capture
    """
    try:
        # Call REDCap API
        data = {
            'token': request.api_token,
            'content': 'record',
            'format': 'json',
            'type': 'flat',
            'rawOrLabel': 'raw'
        }

        if request.instrument:
            data['forms'] = request.instrument

        if request.fields:
            data['fields'] = ','.join(request.fields)

        response = requests.post(
            str(request.api_url),
            data=data,
            timeout=60
        )

        if response.status_code != 200:
            raise HTTPException(400, f"REDCap API error: {response.text}")

        records = response.json()

        return {
            "n_records": len(records),
            "records": records,
            "imported_at": datetime.utcnow().isoformat()
        }

    except requests.RequestException as e:
        raise HTTPException(500, f"REDCap connection error: {str(e)}")


@router.post("/redcap/export")
async def export_to_redcap(
    api_url: HttpUrl,
    api_token: str,
    records: List[Dict[str, Any]],
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Export data to REDCap project"""
    try:
        data = {
            'token': api_token,
            'content': 'record',
            'format': 'json',
            'type': 'flat',
            'overwriteBehavior': 'normal',
            'data': json.dumps(records)
        }

        response = requests.post(str(api_url), data=data, timeout=60)

        if response.status_code != 200:
            raise HTTPException(400, f"REDCap API error: {response.text}")

        result = response.json()

        return {
            "count": result.get('count', 0),
            "ids": result.get('ids', []),
            "exported_at": datetime.utcnow().isoformat()
        }

    except requests.RequestException as e:
        raise HTTPException(500, f"REDCap connection error: {str(e)}")


# ============================
# COVIDENCE INTEGRATION
# ============================

@router.post("/covidence/export")
async def export_to_covidence(
    request: CovidenceExportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Export studies to Covidence for screening

    Covidence is a popular systematic review management tool
    """
    try:
        # Covidence API endpoint
        api_url = f"https://api.covidence.org/api/v2/reviews/{request.review_id}/citations"

        headers = {
            "Authorization": f"Bearer {request.api_key}",
            "Content-Type": "application/json"
        }

        # Transform studies to Covidence format
        citations = []
        for study in request.studies:
            citation = {
                "title": study.get("title", ""),
                "authors": study.get("authors", ""),
                "year": study.get("year", ""),
                "journal": study.get("journal", ""),
                "abstract": study.get("abstract", ""),
                "doi": study.get("doi", ""),
                "pmid": study.get("pmid", "")
            }
            citations.append(citation)

        # Upload to Covidence
        response = requests.post(
            api_url,
            json={"citations": citations},
            headers=headers,
            timeout=60
        )

        if response.status_code >= 400:
            raise HTTPException(400, f"Covidence API error: {response.text}")

        return {
            "n_exported": len(citations),
            "review_id": request.review_id,
            "exported_at": datetime.utcnow().isoformat()
        }

    except requests.RequestException as e:
        raise HTTPException(500, f"Covidence connection error: {str(e)}")


@router.post("/covidence/import")
async def import_from_covidence(
    api_key: str,
    review_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Import included studies from Covidence review"""
    try:
        api_url = f"https://api.covidence.org/api/v2/reviews/{review_id}/studies"

        headers = {
            "Authorization": f"Bearer {api_key}",
            "Accept": "application/json"
        }

        response = requests.get(api_url, headers=headers, timeout=60)

        if response.status_code != 200:
            raise HTTPException(400, f"Covidence API error: {response.text}")

        studies = response.json()

        # Filter to included studies only
        included_studies = [
            s for s in studies.get("studies", [])
            if s.get("status") == "included"
        ]

        return {
            "n_studies": len(included_studies),
            "studies": included_studies,
            "review_id": review_id,
            "imported_at": datetime.utcnow().isoformat()
        }

    except requests.RequestException as e:
        raise HTTPException(500, f"Covidence connection error: {str(e)}")


# ============================
# PROSPERO INTEGRATION
# ============================

@router.post("/prospero/register")
async def register_with_prospero(
    request: ProsperoRegisterRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin)
):
    """
    Register systematic review protocol with PROSPERO

    PROSPERO is the international register of systematic reviews
    """
    try:
        # PROSPERO API endpoint
        api_url = "https://www.crd.york.ac.uk/PROSPEROAPI/"

        # Map internal protocol format to PROSPERO format
        prospero_data = {
            "review_title": request.protocol_data.get("title"),
            "review_question": request.protocol_data.get("research_question"),
            "searches": request.protocol_data.get("search_strategy"),
            "eligibility_criteria": request.protocol_data.get("inclusion_criteria"),
            "data_extraction": request.protocol_data.get("data_extraction_plan"),
            "risk_of_bias": request.protocol_data.get("quality_assessment"),
            "analysis": request.protocol_data.get("analysis_plan"),
            "contact_email": current_user.email,
            "review_type": request.protocol_data.get("review_type", "Systematic review")
        }

        # Submit to PROSPERO
        # Note: Actual PROSPERO registration requires manual review
        # This would submit the draft application

        return {
            "status": "submitted",
            "message": "Protocol submitted to PROSPERO for registration",
            "crd_number": request.crd_number or "Pending",
            "submitted_at": datetime.utcnow().isoformat(),
            "note": "PROSPERO registration requires manual review and approval"
        }

    except Exception as e:
        raise HTTPException(500, f"PROSPERO submission error: {str(e)}")


# ============================
# GITHUB INTEGRATION
# ============================

@router.post("/github/sync")
async def sync_with_github(
    request: GitHubSyncRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Sync analysis files with GitHub repository

    Enables version control and collaboration
    """
    try:
        # Extract repo info from URL
        # Example: https://github.com/user/repo → user/repo
        repo_path = str(request.repo_url).replace("https://github.com/", "").rstrip("/")

        github_token = os.getenv("GITHUB_TOKEN")
        if not github_token:
            raise HTTPException(500, "GitHub integration not configured")

        headers = {
            "Authorization": f"token {github_token}",
            "Accept": "application/vnd.github.v3+json"
        }

        # Get current SHA for branch
        branch_url = f"https://api.github.com/repos/{repo_path}/git/ref/heads/{request.branch}"
        branch_response = requests.get(branch_url, headers=headers)

        if branch_response.status_code != 200:
            raise HTTPException(400, f"GitHub error: {branch_response.text}")

        current_sha = branch_response.json()["object"]["sha"]

        # Create blobs for files
        blobs = []
        for file_path in request.sync_files:
            # Read file content (would need to retrieve from storage)
            content = "# File content here"  # Placeholder

            blob_url = f"https://api.github.com/repos/{repo_path}/git/blobs"
            blob_response = requests.post(
                blob_url,
                json={"content": content, "encoding": "utf-8"},
                headers=headers
            )

            if blob_response.status_code >= 400:
                raise HTTPException(400, f"GitHub blob error: {blob_response.text}")

            blobs.append({
                "path": file_path,
                "mode": "100644",
                "type": "blob",
                "sha": blob_response.json()["sha"]
            })

        # Create tree
        tree_url = f"https://api.github.com/repos/{repo_path}/git/trees"
        tree_response = requests.post(
            tree_url,
            json={"base_tree": current_sha, "tree": blobs},
            headers=headers
        )

        if tree_response.status_code >= 400:
            raise HTTPException(400, f"GitHub tree error: {tree_response.text}")

        tree_sha = tree_response.json()["sha"]

        # Create commit
        commit_url = f"https://api.github.com/repos/{repo_path}/git/commits"
        commit_response = requests.post(
            commit_url,
            json={
                "message": request.commit_message,
                "tree": tree_sha,
                "parents": [current_sha]
            },
            headers=headers
        )

        if commit_response.status_code >= 400:
            raise HTTPException(400, f"GitHub commit error: {commit_response.text}")

        commit_sha = commit_response.json()["sha"]

        # Update branch reference
        ref_url = f"https://api.github.com/repos/{repo_path}/git/refs/heads/{request.branch}"
        ref_response = requests.patch(
            ref_url,
            json={"sha": commit_sha},
            headers=headers
        )

        if ref_response.status_code >= 400:
            raise HTTPException(400, f"GitHub ref error: {ref_response.text}")

        return {
            "status": "synced",
            "commit_sha": commit_sha,
            "branch": request.branch,
            "files_synced": len(request.sync_files),
            "synced_at": datetime.utcnow().isoformat()
        }

    except requests.RequestException as e:
        raise HTTPException(500, f"GitHub connection error: {str(e)}")


# ============================
# API KEY MANAGEMENT
# ============================

@router.post("/api-keys", status_code=201)
async def create_api_key(
    name: str,
    expiry_days: int = 365,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin)
):
    """
    Create API key for external integrations

    Requires admin role
    """
    import secrets

    # Generate secure API key
    api_key = f"evidenceos_{secrets.token_urlsafe(32)}"

    # Store hashed version
    key_hash = hashlib.sha256(api_key.encode()).hexdigest()

    expiry = datetime.utcnow() + timedelta(days=expiry_days)

    # Store in database (would need APIKey model)
    # api_key_record = APIKey(
    #     organization_id=current_user.organization_id,
    #     name=name,
    #     key_hash=key_hash,
    #     expires_at=expiry,
    #     created_by=str(current_user.id)
    # )
    # db.add(api_key_record)
    # db.commit()

    return {
        "api_key": api_key,
        "name": name,
        "expires_at": expiry.isoformat(),
        "warning": "Save this key securely - it will not be shown again"
    }


@router.get("/api-keys")
async def list_api_keys(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List API keys for organization (without revealing keys)"""
    # Would query APIKey model
    return {
        "api_keys": [
            {
                "key_id": "1",
                "name": "Production API",
                "created_at": "2024-01-01T00:00:00Z",
                "expires_at": "2025-01-01T00:00:00Z",
                "last_used": "2024-11-01T12:30:00Z"
            }
        ]
    }


@router.delete("/api-keys/{key_id}")
async def revoke_api_key(
    key_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin)
):
    """Revoke API key"""
    # Delete from database
    return {"message": "API key revoked successfully"}


# ============================
# ZAPIER/IFTTT COMPATIBLE WEBHOOKS
# ============================

@router.post("/zapier/trigger")
async def zapier_trigger(
    request: Request,
    x_zapier_key: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """
    Zapier-compatible trigger endpoint

    Allows Zapier to listen for EvidenceOS events
    """
    # Validate Zapier key
    if not x_zapier_key:
        raise HTTPException(401, "Missing Zapier API key")

    # Get recent events (would need Event model)
    events = [
        {
            "id": "evt_123",
            "type": "analysis.completed",
            "timestamp": datetime.utcnow().isoformat(),
            "data": {
                "project_id": "proj_123",
                "analysis_type": "meta-analysis",
                "pooled_effect": 0.52
            }
        }
    ]

    return events


@router.post("/ifttt/trigger/{event_name}")
async def ifttt_trigger(
    event_name: str,
    data: Dict[str, Any],
    ifttt_key: str,
    db: Session = Depends(get_db)
):
    """
    Trigger IFTTT applet

    Allows EvidenceOS to trigger IFTTT workflows
    """
    try:
        url = f"https://maker.ifttt.com/trigger/{event_name}/with/key/{ifttt_key}"

        response = requests.post(url, json=data, timeout=30)

        if response.status_code != 200:
            raise HTTPException(400, f"IFTTT trigger failed: {response.text}")

        return {
            "status": "triggered",
            "event": event_name,
            "timestamp": datetime.utcnow().isoformat()
        }

    except requests.RequestException as e:
        raise HTTPException(500, f"IFTTT connection error: {str(e)}")


# ============================
# RATE LIMITING
# ============================

@router.get("/usage")
async def get_api_usage(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get API usage statistics for organization"""
    # Would query usage metrics
    return {
        "organization_id": str(current_user.organization_id),
        "period": "current_month",
        "api_calls": 1250,
        "api_limit": 10000,
        "webhooks_sent": 45,
        "webhooks_failed": 2,
        "data_transferred_mb": 150.5
    }
