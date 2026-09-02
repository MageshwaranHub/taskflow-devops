import pytest
from app.app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True

    with app.test_client() as client:
        yield client


def test_health(client):
    response = client.get("/health")

    assert response.status_code == 200

    data = response.get_json()

    assert data["status"] == "healthy"
    assert data["application"] == "TaskFlow"


def test_home_page(client):
    response = client.get("/")

    assert response.status_code == 200


def test_api_tasks(client):
    response = client.get("/api/tasks")

    assert response.status_code == 200
    assert isinstance(response.get_json(), list)
