from controllers.commute_status_controller import get_status


def test_get_status(monkeypatch):
    thresholds = object()
    called = {}

    def fake_service(arg):
        called['arg'] = arg
        return {'ok': True}

    monkeypatch.setattr('controllers.commute_status_controller.get_commute_status', fake_service)
    result = get_status(thresholds)
    assert result == {'ok': True}
    assert called['arg'] is thresholds
