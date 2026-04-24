import pymysql
from pymysql.cursors import Cursor

from core.config import DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME


def get_db_connection() -> pymysql.connections.Connection:
    """
    Retourne une connexion MariaDB/PyMySQL.
    Lève une RuntimeError claire si la connexion échoue.
    """
    try:
        conn = pymysql.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            cursorclass=Cursor,
            autocommit=False,
        )
        return conn
    except Exception as exc:
        raise RuntimeError(f"Erreur de connexion MariaDB: {exc}") from exc