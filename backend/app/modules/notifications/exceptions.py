class NotificationNotFoundError(Exception):
    def __init__(self, id: int):
        self.id = id
        super().__init__(f"Notification con id {id} no encontrado")


class NotificationAlreadyExistsError(Exception):
    def __init__(self, detail: str = ""):
        super().__init__(f"Notification ya existe. {detail}".strip())
