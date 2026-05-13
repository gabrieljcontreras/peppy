"""
Fernet-based encryption for sensitive data (OAuth tokens, etc.).

The encryption key should be a 32-byte URL-safe base64-encoded string.
Generate one with: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
"""
import base64
import hashlib
from typing import Optional
from cryptography.fernet import Fernet, InvalidToken
from functools import lru_cache

from app.config import get_settings, _DEFAULT_ENCRYPTION_KEY


class EncryptionError(Exception):
    """Raised when encryption/decryption fails."""


@lru_cache
def _get_fernet() -> Fernet:
    settings = get_settings()
    key = settings.encryption_key

    if key == _DEFAULT_ENCRYPTION_KEY:
        if not settings.debug:
            raise EncryptionError(
                "ENCRYPTION_KEY not configured for production. "
                "Generate one with: python -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\""
            )
        # In debug mode, derive a stable key from the default for dev/test convenience
        derived = hashlib.sha256(b"peppy-dev-key").digest()
        key = base64.urlsafe_b64encode(derived).decode()

    try:
        return Fernet(key.encode())
    except Exception as e:
        raise EncryptionError(f"Invalid encryption key format: {e}")


def encrypt_token(plaintext: Optional[str]) -> Optional[str]:
    """Encrypt a token string. Returns None if input is None."""
    if plaintext is None:
        return None
    fernet = _get_fernet()
    return fernet.encrypt(plaintext.encode()).decode()


def decrypt_token(ciphertext: Optional[str]) -> Optional[str]:
    """Decrypt a token string. Returns None if input is None."""
    if ciphertext is None:
        return None
    fernet = _get_fernet()
    try:
        return fernet.decrypt(ciphertext.encode()).decode()
    except InvalidToken:
        raise EncryptionError("Failed to decrypt token — key mismatch or corrupted data")
