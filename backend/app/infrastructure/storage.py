# infrastructure/storage.py

import aiobotocore.session
from app.core.config import settings


async def upload_file(key: str, data: bytes, content_type: str) -> str:
    """Sube un archivo a S3/MinIO y devuelve la URL pública."""
    session = aiobotocore.session.get_session()
    async with session.create_client(
        "s3",
        endpoint_url=settings.S3_ENDPOINT,  # None para AWS S3 real
        aws_access_key_id=settings.S3_ACCESS_KEY,
        aws_secret_access_key=settings.S3_SECRET_KEY,
        region_name=settings.S3_REGION,
    ) as client:
        await client.put_object(
            Bucket=settings.S3_BUCKET, Key=key, Body=data, ContentType=content_type
        )
        return f"{settings.S3_PUBLIC}/{key}"


async def delete_file(key: str) -> None:
    session = aiobotocore.session.get_session()
    async with session.create_client("s3", ...) as client:
        await client.delete_object(Bucket=settings.S3_BUCKET, Key=key)
