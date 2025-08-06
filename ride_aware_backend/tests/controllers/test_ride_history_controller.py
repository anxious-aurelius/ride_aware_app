import asyncio
from controllers import ride_history_controller


class DummyCollection:
    def __init__(self):
        self.args = None

    async def update_one(self, filter_doc, update_doc, upsert=False):
        self.args = (filter_doc, update_doc, upsert)


def test_create_history_entry_resets_document(monkeypatch):
    dummy = DummyCollection()
    monkeypatch.setattr(ride_history_controller, "ride_history_collection", dummy)

    asyncio.run(
        ride_history_controller.create_history_entry(
            "dev1", "th1", "2024-01-01", "08:00", "09:00"
        )
    )

    assert dummy.args is not None
    filter_doc, update_doc, upsert = dummy.args
    assert filter_doc == {"threshold_id": "th1"}
    assert update_doc["$set"]["feedback"] is None
    assert upsert is True
