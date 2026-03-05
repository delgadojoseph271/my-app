import pytest
from unittest.mock import AsyncMock, MagicMock
from app.modules.auth.service import AuthService
from app.modules.auth.schemas import AuthCreateSchema


@pytest.fixture
def mock_repo():
    return AsyncMock()


@pytest.fixture
def service(mock_repo):
    return AuthService(mock_repo)


@pytest.mark.asyncio
async def test_get_by_id_calls_repo(service, mock_repo):
    mock_repo.get_or_404.return_value = MagicMock(id=1)
    result = await service.get_by_id(1)
    mock_repo.get_or_404.assert_called_once_with(1)
    assert result.id == 1


# Agregá más tests aquí
