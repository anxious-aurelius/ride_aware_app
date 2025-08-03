from datetime import datetime, time, timedelta

from utils.commute_window import (
    parse_time,
    is_within_commute_window,
    commute_window_duration,
)


def test_parse_time():
    assert parse_time("08:30") == time(8, 30)


def test_is_within_commute_window_normal():
    start = time(8, 0)
    end = time(9, 0)
    assert is_within_commute_window(datetime(2023, 1, 1, 8, 30), start, end)
    assert not is_within_commute_window(datetime(2023, 1, 1, 10, 0), start, end)


def test_is_within_commute_window_wraparound():
    start = time(22, 0)
    end = time(2, 0)
    assert is_within_commute_window(datetime(2023, 1, 1, 23, 0), start, end)
    assert is_within_commute_window(datetime(2023, 1, 2, 1, 0), start, end)
    assert not is_within_commute_window(datetime(2023, 1, 2, 3, 0), start, end)


def test_commute_window_duration():
    assert commute_window_duration(time(8, 0), time(9, 0)) == timedelta(hours=1)
    assert commute_window_duration(time(22, 0), time(2, 0)) == timedelta(hours=4)
