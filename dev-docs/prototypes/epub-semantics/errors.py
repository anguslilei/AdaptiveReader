"""Validation failures in the developer reference prototype."""
class SourceError(ValueError):
    pass


def check_cancelled(cancelled):
    if cancelled():
        raise SourceError('operation cancelled')
