"""initial

Revision ID: 208ce85f219d
Revises:
Create Date: 2026-03-07 18:44:56.834520

"""

from typing import Sequence, Union


# revision identifiers, used by Alembic.
revision: str = "208ce85f219d"
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
