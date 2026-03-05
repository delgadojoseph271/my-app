class AuthNotFoundError(Exception):
    def __init__(self, id: int):
        self.id = id
        super().__init__(f"Auth con id {id} no encontrado")


class AuthAlreadyExistsError(Exception):
    def __init__(self, detail: str = ""):
        super().__init__(f"Auth ya existe. {detail}".strip())
