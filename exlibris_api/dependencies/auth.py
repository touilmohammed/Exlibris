from typing import Optional

from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from core.security import decode_access_token


bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user_id(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme)
) -> int:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Token manquant")

    token = credentials.credentials

    try:
        payload = decode_access_token(token)
        user_id_raw = payload.get("sub")
        if user_id_raw is None:
            raise HTTPException(status_code=401, detail="Token invalide")
        return int(user_id_raw)
    except ValueError:
        raise HTTPException(status_code=401, detail="Token invalide ou expiré")
    except Exception:
        raise HTTPException(status_code=401, detail="Token invalide ou expiré")