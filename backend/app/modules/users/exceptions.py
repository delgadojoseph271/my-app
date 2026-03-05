class UserNotFoundError(Exception):
    def __init__(self, id: int):
        self.id = id
        super().__init__(f"User con id {id} no encontrado")


class UserAlreadyExistsError(Exception):
    def __init__(self, detail: str = ""):
        super().__init__(f"User ya existe. {detail}".strip())
