"""
SaaS Billing System for EvidenceOS PRIME
Stripe integration for subscription management and usage-based billing
"""
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import Dict, List, Optional
from datetime import datetime, timedelta
from pydantic import BaseModel
import os

try:
    import stripe
    STRIPE_AVAILABLE = True
    stripe.api_key = os.getenv("STRIPE_SECRET_KEY", "sk_test_...")
except ImportError:
    STRIPE_AVAILABLE = False

from database.database import get_db, get_tenant_db
from database.models import Organization, User, UsageMetric
from api.security import get_current_user, get_current_active_admin

router = APIRouter(prefix="/billing", tags=["Billing"])


# Pydantic models
class SubscriptionPlan(BaseModel):
    """Subscription plan details"""
    name: str
    tier: str  # starter, professional, enterprise
    price_monthly: int  # in cents
    price_annual: int  # in cents
    max_users: int
    max_projects: int
    storage_gb: int
    features: List[str]


class CreateSubscriptionRequest(BaseModel):
    """Request to create subscription"""
    organization_id: str
    plan: str  # starter, professional, enterprise
    billing_cycle: str = "monthly"  # monthly, annual
    payment_method_id: str


class UpdateSubscriptionRequest(BaseModel):
    """Request to update subscription"""
    new_plan: str
    prorate: bool = True


class UsageSummary(BaseModel):
    """Usage summary for organization"""
    organization_id: str
    billing_period_start: datetime
    billing_period_end: datetime
    meta_analyses_run: int
    reports_generated: int
    api_calls: int
    storage_used_gb: float
    overage_charges: float


# Pricing tiers configuration
PRICING_TIERS = {
    "starter": {
        "name": "Starter",
        "price_monthly": 500000,  # $5,000/month
        "price_annual": 5400000,  # $54,000/year (10% discount)
        "max_users": 5,
        "max_projects": 50,
        "storage_gb": 10,
        "stripe_price_id_monthly": "price_starter_monthly",
        "stripe_price_id_annual": "price_starter_annual",
        "features": [
            "5 users",
            "50 projects",
            "10 GB storage",
            "Core meta-analysis",
            "Email support"
        ]
    },
    "professional": {
        "name": "Professional",
        "price_monthly": 2000000,  # $20,000/month
        "price_annual": 21600000,  # $216,000/year (10% discount)
        "max_users": 25,
        "max_projects": 500,
        "storage_gb": 100,
        "stripe_price_id_monthly": "price_pro_monthly",
        "stripe_price_id_annual": "price_pro_annual",
        "features": [
            "25 users",
            "Unlimited projects",
            "100 GB storage",
            "Advanced meta-analysis",
            "Bayesian NMA",
            "Priority support",
            "White-label reports"
        ]
    },
    "enterprise": {
        "name": "Enterprise",
        "price_monthly": 10000000,  # $100,000/month
        "price_annual": 108000000,  # $1,080,000/year (10% discount)
        "max_users": -1,  # Unlimited
        "max_projects": -1,  # Unlimited
        "storage_gb": 1000,
        "stripe_price_id_monthly": "price_enterprise_monthly",
        "stripe_price_id_annual": "price_enterprise_annual",
        "features": [
            "Unlimited users",
            "Unlimited projects",
            "1 TB storage",
            "All features",
            "Bayesian NMA",
            "Dedicated instance",
            "SLA guarantees",
            "Custom integrations",
            "24/7 support"
        ]
    }
}


@router.get("/plans")
async def get_pricing_plans() -> List[Dict]:
    """Get available subscription plans"""
    plans = []
    for tier, details in PRICING_TIERS.items():
        plans.append({
            "tier": tier,
            "name": details["name"],
            "price_monthly": details["price_monthly"] / 100,  # Convert cents to dollars
            "price_annual": details["price_annual"] / 100,
            "max_users": details["max_users"],
            "max_projects": details["max_projects"],
            "storage_gb": details["storage_gb"],
            "features": details["features"]
        })
    return plans


@router.post("/create-subscription")
async def create_subscription(
    request: CreateSubscriptionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin)
):
    """
    Create a new subscription for organization

    Requires admin role
    """
    if not STRIPE_AVAILABLE:
        raise HTTPException(500, "Stripe not configured")

    # Get organization
    org = db.query(Organization).filter(Organization.id == request.organization_id).first()
    if not org:
        raise HTTPException(404, "Organization not found")

    # Verify user is admin of this organization
    if current_user.organization_id != org.id or current_user.role != "admin":
        raise HTTPException(403, "Admin access required")

    # Get plan details
    plan = PRICING_TIERS.get(request.plan)
    if not plan:
        raise HTTPException(400, f"Invalid plan: {request.plan}")

    try:
        # Create or get Stripe customer
        if org.stripe_customer_id:
            customer = stripe.Customer.retrieve(org.stripe_customer_id)
        else:
            customer = stripe.Customer.create(
                email=org.admin_email,
                name=org.name,
                metadata={"organization_id": str(org.id)}
            )
            org.stripe_customer_id = customer.id

        # Attach payment method
        stripe.PaymentMethod.attach(
            request.payment_method_id,
            customer=customer.id
        )

        # Set as default payment method
        stripe.Customer.modify(
            customer.id,
            invoice_settings={"default_payment_method": request.payment_method_id}
        )

        # Create subscription
        price_id = (
            plan["stripe_price_id_annual"]
            if request.billing_cycle == "annual"
            else plan["stripe_price_id_monthly"]
        )

        subscription = stripe.Subscription.create(
            customer=customer.id,
            items=[{"price": price_id}],
            metadata={
                "organization_id": str(org.id),
                "plan": request.plan
            }
        )

        # Update organization
        org.subscription_tier = request.plan
        org.stripe_subscription_id = subscription.id
        org.subscription_status = subscription.status
        org.max_users = plan["max_users"]
        org.max_projects = plan["max_projects"]
        org.storage_limit_gb = plan["storage_gb"]

        db.commit()

        return {
            "subscription_id": subscription.id,
            "status": subscription.status,
            "plan": request.plan,
            "billing_cycle": request.billing_cycle,
            "current_period_end": datetime.fromtimestamp(subscription.current_period_end)
        }

    except stripe.error.StripeError as e:
        raise HTTPException(400, f"Stripe error: {str(e)}")


@router.get("/subscription")
async def get_subscription(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get current subscription details for organization"""
    org = db.query(Organization).filter(Organization.id == current_user.organization_id).first()

    if not org.stripe_subscription_id:
        return {
            "status": "no_subscription",
            "plan": org.subscription_tier,
            "trial": True if org.trial_ends_at and org.trial_ends_at > datetime.utcnow() else False
        }

    if not STRIPE_AVAILABLE:
        return {
            "status": org.subscription_status,
            "plan": org.subscription_tier
        }

    try:
        subscription = stripe.Subscription.retrieve(org.stripe_subscription_id)

        return {
            "subscription_id": subscription.id,
            "status": subscription.status,
            "plan": org.subscription_tier,
            "billing_cycle": "annual" if subscription.items.data[0].plan.interval == "year" else "monthly",
            "current_period_start": datetime.fromtimestamp(subscription.current_period_start),
            "current_period_end": datetime.fromtimestamp(subscription.current_period_end),
            "cancel_at_period_end": subscription.cancel_at_period_end,
            "amount": subscription.items.data[0].plan.amount / 100  # Convert cents to dollars
        }

    except stripe.error.StripeError as e:
        raise HTTPException(400, f"Stripe error: {str(e)}")


@router.put("/subscription/upgrade")
async def upgrade_subscription(
    request: UpdateSubscriptionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin)
):
    """
    Upgrade/downgrade subscription plan

    Requires admin role
    """
    if not STRIPE_AVAILABLE:
        raise HTTPException(500, "Stripe not configured")

    org = db.query(Organization).filter(Organization.id == current_user.organization_id).first()

    if not org.stripe_subscription_id:
        raise HTTPException(400, "No active subscription")

    # Get new plan details
    new_plan = PRICING_TIERS.get(request.new_plan)
    if not new_plan:
        raise HTTPException(400, f"Invalid plan: {request.new_plan}")

    try:
        subscription = stripe.Subscription.retrieve(org.stripe_subscription_id)

        # Get current billing cycle
        billing_cycle = "annual" if subscription.items.data[0].plan.interval == "year" else "monthly"
        new_price_id = (
            new_plan["stripe_price_id_annual"]
            if billing_cycle == "annual"
            else new_plan["stripe_price_id_monthly"]
        )

        # Update subscription
        updated_subscription = stripe.Subscription.modify(
            org.stripe_subscription_id,
            items=[{
                "id": subscription.items.data[0].id,
                "price": new_price_id
            }],
            proration_behavior="always_invoice" if request.prorate else "none"
        )

        # Update organization
        org.subscription_tier = request.new_plan
        org.max_users = new_plan["max_users"]
        org.max_projects = new_plan["max_projects"]
        org.storage_limit_gb = new_plan["storage_gb"]

        db.commit()

        return {
            "subscription_id": updated_subscription.id,
            "new_plan": request.new_plan,
            "status": updated_subscription.status,
            "effective_date": datetime.fromtimestamp(updated_subscription.current_period_end)
        }

    except stripe.error.StripeError as e:
        raise HTTPException(400, f"Stripe error: {str(e)}")


@router.delete("/subscription/cancel")
async def cancel_subscription(
    cancel_immediately: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_admin)
):
    """
    Cancel subscription

    Requires admin role
    """
    if not STRIPE_AVAILABLE:
        raise HTTPException(500, "Stripe not configured")

    org = db.query(Organization).filter(Organization.id == current_user.organization_id).first()

    if not org.stripe_subscription_id:
        raise HTTPException(400, "No active subscription")

    try:
        if cancel_immediately:
            # Cancel immediately
            subscription = stripe.Subscription.delete(org.stripe_subscription_id)
            org.subscription_status = "canceled"
        else:
            # Cancel at period end
            subscription = stripe.Subscription.modify(
                org.stripe_subscription_id,
                cancel_at_period_end=True
            )
            org.subscription_status = "active"  # Still active until period end

        db.commit()

        return {
            "subscription_id": subscription.id,
            "status": "canceled" if cancel_immediately else "active",
            "cancel_at_period_end": not cancel_immediately,
            "access_until": datetime.fromtimestamp(subscription.current_period_end) if not cancel_immediately else datetime.utcnow()
        }

    except stripe.error.StripeError as e:
        raise HTTPException(400, f"Stripe error: {str(e)}")


@router.get("/usage")
async def get_usage(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get usage metrics for current billing period"""
    org_id = current_user.organization_id

    # Default to current month
    if not start_date:
        start = datetime.utcnow().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    else:
        start = datetime.fromisoformat(start_date)

    if not end_date:
        end = datetime.utcnow()
    else:
        end = datetime.fromisoformat(end_date)

    # Query usage metrics
    metrics = db.query(UsageMetric).filter(
        UsageMetric.organization_id == org_id,
        UsageMetric.timestamp >= start,
        UsageMetric.timestamp <= end
    ).all()

    # Aggregate by metric type
    usage_summary = {
        "meta_analyses_run": 0,
        "reports_generated": 0,
        "api_calls": 0,
        "storage_used_gb": 0,
        "total_actions": len(metrics)
    }

    for metric in metrics:
        if metric.metric_type in usage_summary:
            usage_summary[metric.metric_type] += metric.metric_value

    return {
        "organization_id": str(org_id),
        "billing_period_start": start,
        "billing_period_end": end,
        "usage": usage_summary
    }


@router.post("/usage/track")
async def track_usage_metric(
    metric_type: str,
    metric_value: float = 1.0,
    project_id: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Track a usage metric

    Called internally by the application
    """
    from database.database import track_usage

    track_usage(
        db,
        organization_id=str(current_user.organization_id),
        user_id=str(current_user.id),
        metric_type=metric_type,
        metric_value=metric_value,
        project_id=project_id
    )

    return {"status": "tracked", "metric_type": metric_type}


@router.get("/invoices")
async def get_invoices(
    limit: int = 10,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get invoice history"""
    if not STRIPE_AVAILABLE:
        raise HTTPException(500, "Stripe not configured")

    org = db.query(Organization).filter(Organization.id == current_user.organization_id).first()

    if not org.stripe_customer_id:
        return {"invoices": []}

    try:
        invoices = stripe.Invoice.list(
            customer=org.stripe_customer_id,
            limit=limit
        )

        return {
            "invoices": [
                {
                    "id": inv.id,
                    "number": inv.number,
                    "amount_due": inv.amount_due / 100,
                    "amount_paid": inv.amount_paid / 100,
                    "status": inv.status,
                    "created": datetime.fromtimestamp(inv.created),
                    "due_date": datetime.fromtimestamp(inv.due_date) if inv.due_date else None,
                    "invoice_pdf": inv.invoice_pdf
                }
                for inv in invoices.data
            ]
        }

    except stripe.error.StripeError as e:
        raise HTTPException(400, f"Stripe error: {str(e)}")


def check_subscription_limits(db: Session, organization_id: str, limit_type: str) -> bool:
    """
    Check if organization has exceeded subscription limits

    Args:
        db: Database session
        organization_id: Organization UUID
        limit_type: Type of limit to check (users, projects, storage)

    Returns:
        True if within limits, False if exceeded
    """
    org = db.query(Organization).filter(Organization.id == organization_id).first()

    if not org:
        return False

    if limit_type == "users":
        user_count = db.query(User).filter(
            User.organization_id == organization_id,
            User.is_active == True
        ).count()
        return org.max_users == -1 or user_count < org.max_users

    elif limit_type == "projects":
        from database.models import Project
        project_count = db.query(Project).filter(
            Project.organization_id == organization_id
        ).count()
        return org.max_projects == -1 or project_count < org.max_projects

    elif limit_type == "storage":
        # TODO: Calculate actual storage usage
        return True  # For now, assume within limits

    return True


def enforce_limits_middleware(db: Session, organization_id: str, action: str):
    """
    Middleware to enforce subscription limits

    Raises HTTPException if limits exceeded
    """
    if action == "create_user":
        if not check_subscription_limits(db, organization_id, "users"):
            raise HTTPException(
                403,
                "User limit exceeded for your subscription tier. Please upgrade to add more users."
            )

    elif action == "create_project":
        if not check_subscription_limits(db, organization_id, "projects"):
            raise HTTPException(
                403,
                "Project limit exceeded for your subscription tier. Please upgrade or archive old projects."
            )

    elif action == "upload_file":
        if not check_subscription_limits(db, organization_id, "storage"):
            raise HTTPException(
                403,
                "Storage limit exceeded for your subscription tier. Please upgrade or delete old files."
            )
