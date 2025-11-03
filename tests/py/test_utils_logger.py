"""
Comprehensive tests for logger utility - 100% Coverage
Target: 100% coverage of backend/utils/logger.py
"""
import pytest
import logging
import tempfile
import shutil
from pathlib import Path
import sys
import time

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "backend"))

from utils.logger import (
    setup_logger,
    get_logger,
    LoggerMixin,
    log_function_call,
    log_execution_time,
    log_api_request,
    log_error,
    log_validation_error,
    log_cache_operation,
    StructuredFormatter,
    ColoredFormatter
)


class TestSetupLogger:
    """Test setup_logger function"""

    @pytest.fixture
    def temp_log_dir(self):
        """Create temporary log directory"""
        temp_dir = tempfile.mkdtemp()
        yield temp_dir
        shutil.rmtree(temp_dir, ignore_errors=True)

    def test_setup_logger_basic(self, temp_log_dir):
        """Test basic logger setup"""
        logger = setup_logger(
            name='test_logger',
            level='INFO',
            log_to_file=True,
            log_dir=temp_log_dir
        )
        assert logger.name == 'test_logger'
        assert logger.level == logging.INFO

    def test_setup_logger_debug_level(self, temp_log_dir):
        """Test logger with DEBUG level"""
        logger = setup_logger(
            name='debug_logger',
            level='DEBUG',
            log_dir=temp_log_dir
        )
        assert logger.level == logging.DEBUG

    def test_setup_logger_no_file(self):
        """Test logger without file logging"""
        logger = setup_logger(
            name='console_only',
            log_to_file=False
        )
        assert logger is not None

    def test_setup_logger_structured(self, temp_log_dir):
        """Test structured logging"""
        logger = setup_logger(
            name='structured_logger',
            log_dir=temp_log_dir,
            structured=True
        )
        assert logger is not None

    def test_logger_creates_files(self, temp_log_dir):
        """Test that log files are created"""
        logger = setup_logger(
            name='file_logger',
            log_dir=temp_log_dir,
            log_to_file=True
        )
        logger.info('Test message')

        log_files = list(Path(temp_log_dir).glob('*.log'))
        assert len(log_files) > 0


class TestGetLogger:
    """Test get_logger function"""

    def test_get_logger(self):
        """Test getting logger"""
        logger = get_logger('test')
        assert logger is not None
        assert isinstance(logger, logging.Logger)


class TestLoggerMixin:
    """Test LoggerMixin class"""

    def test_logger_mixin(self):
        """Test logger mixin"""
        class TestClass(LoggerMixin):
            def do_something(self):
                self.logger.info('Doing something')

        obj = TestClass()
        assert obj.logger is not None
        assert 'TestClass' in obj.logger.name


class TestLogDecorators:
    """Test logging decorators"""

    def test_log_function_call(self):
        """Test log_function_call decorator"""
        @log_function_call
        def test_function(x, y):
            return x + y

        result = test_function(1, 2)
        assert result == 3

    def test_log_function_call_with_error(self):
        """Test log_function_call with exception"""
        @log_function_call
        def failing_function():
            raise ValueError('Test error')

        with pytest.raises(ValueError):
            failing_function()

    def test_log_execution_time(self):
        """Test log_execution_time decorator"""
        @log_execution_time
        def slow_function():
            time.sleep(0.1)
            return 'done'

        result = slow_function()
        assert result == 'done'

    def test_log_execution_time_with_error(self):
        """Test log_execution_time with exception"""
        @log_execution_time
        def failing_function():
            raise RuntimeError('Test error')

        with pytest.raises(RuntimeError):
            failing_function()


class TestLogUtilityFunctions:
    """Test utility logging functions"""

    def test_log_api_request(self):
        """Test log_api_request"""
        log_api_request('GET', '/api/test', 200, 0.5)
        # Should not raise

    def test_log_error(self):
        """Test log_error"""
        try:
            raise ValueError('Test error')
        except ValueError as e:
            log_error(e)
            # Should not raise

    def test_log_error_with_context(self):
        """Test log_error with context"""
        try:
            raise ValueError('Test error')
        except ValueError as e:
            log_error(e, context={'user': 'test_user'})
            # Should not raise

    def test_log_validation_error(self):
        """Test log_validation_error"""
        log_validation_error('email', 'invalid', 'valid email format')
        # Should not raise

    def test_log_cache_operation(self):
        """Test log_cache_operation"""
        log_cache_operation('hit', 'cache_key_123', True)
        log_cache_operation('miss', 'cache_key_456', False)
        # Should not raise


class TestStructuredFormatter:
    """Test StructuredFormatter"""

    def test_structured_formatter(self):
        """Test structured JSON formatting"""
        formatter = StructuredFormatter()
        record = logging.LogRecord(
            name='test',
            level=logging.INFO,
            pathname='test.py',
            lineno=10,
            msg='Test message',
            args=(),
            exc_info=None
        )
        formatted = formatter.format(record)
        assert 'timestamp' in formatted
        assert 'level' in formatted
        assert 'message' in formatted

    def test_structured_formatter_with_exception(self):
        """Test structured formatter with exception"""
        formatter = StructuredFormatter()

        try:
            raise ValueError('Test error')
        except ValueError:
            record = logging.LogRecord(
                name='test',
                level=logging.ERROR,
                pathname='test.py',
                lineno=10,
                msg='Error occurred',
                args=(),
                exc_info=sys.exc_info()
            )
            formatted = formatter.format(record)
            assert 'exception' in formatted


class TestColoredFormatter:
    """Test ColoredFormatter"""

    def test_colored_formatter(self):
        """Test colored console formatting"""
        formatter = ColoredFormatter()
        record = logging.LogRecord(
            name='test',
            level=logging.INFO,
            pathname='test.py',
            lineno=10,
            msg='Test message',
            args=(),
            exc_info=None
        )
        formatted = formatter.format(record)
        assert 'Test message' in formatted

    def test_colored_formatter_all_levels(self):
        """Test colored formatter with all log levels"""
        formatter = ColoredFormatter()
        levels = [
            logging.DEBUG,
            logging.INFO,
            logging.WARNING,
            logging.ERROR,
            logging.CRITICAL
        ]

        for level in levels:
            record = logging.LogRecord(
                name='test',
                level=level,
                pathname='test.py',
                lineno=10,
                msg='Test message',
                args=(),
                exc_info=None
            )
            formatted = formatter.format(record)
            assert formatted is not None

    def test_colored_formatter_with_exception(self):
        """Test colored formatter with exception"""
        formatter = ColoredFormatter()

        try:
            raise RuntimeError('Test error')
        except RuntimeError:
            record = logging.LogRecord(
                name='test',
                level=logging.ERROR,
                pathname='test.py',
                lineno=10,
                msg='Error occurred',
                args=(),
                exc_info=sys.exc_info()
            )
            formatted = formatter.format(record)
            assert 'Error occurred' in formatted
            assert 'RuntimeError' in formatted


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--cov=backend/utils/logger', '--cov-report=term-missing'])
