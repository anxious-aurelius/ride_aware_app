import asyncio
from controllers.commute_status_controller import get_status


def test_get_status(monkeypatch):
    called = {}

    async def fake_service(arg):
        called['arg'] = arg
        return {'ok': True}

    monkeypatch.setattr('controllers.commute_status_controller.get_commute_status', fake_service)
    result = asyncio.run(get_status('device123'))
    assert result == {'ok': True}
    assert called['arg'] == 'device123'
