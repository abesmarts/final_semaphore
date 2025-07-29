import logging
import sys


def setup_logging(script_name, log_level='INFO'):
    """
    Setup centralized logging configuration
    
    Args:
        script_name: Name of the script for log identification
        log_level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
    """
    
    # Create logger
    logger = logging.getLogger(script_name)
    logger.setLevel(getattr(logging, log_level.upper()))
    
    # Clear any existing handlers
    logger.handlers.clear()
    
    # Create formatter
    formatter = logging.Formatter(
        fmt='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(getattr(logging, log_level.upper()))
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # File handler (optional, if running in persistent environment)
    try:
        file_handler = logging.FileHandler(f'/var/log/{script_name}.log')
        file_handler.setLevel(getattr(logging, log_level.upper()))
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    except (OSError, PermissionError):
        # If can't write to /var/log, just use console logging
        pass
    
    return logger