from app.services.auth import create_access_token, create_refresh_token, decode_token


async def test_password_change_invalidates_old_access_and_refresh_tokens(client):
    registered = await client.post(
        "/api/v1/auth/register",
        json={"email": "rotate@example.com", "password": "password123"},
    )
    old = registered.json()
    assert decode_token(old["access_token"])["ver"] == 1
    assert decode_token(old["refresh_token"])["ver"] == 1

    response = await client.post(
        "/api/v1/auth/change-password",
        headers={"Authorization": f"Bearer {old['access_token']}"},
        json={"current_password": "password123", "new_password": "replacement456"},
    )

    assert response.status_code == 204
    assert (
        await client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {old['access_token']}"},
        )
    ).status_code == 401
    assert (
        await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": old["refresh_token"]},
        )
    ).status_code == 401
    assert (
        await client.post(
            "/api/v1/auth/login",
            json={"email": "rotate@example.com", "password": "password123"},
        )
    ).status_code == 401

    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "rotate@example.com", "password": "replacement456"},
    )
    assert login.status_code == 200
    replacement = login.json()
    assert (
        await client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {replacement['access_token']}"},
        )
    ).status_code == 200

    refreshed = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": replacement["refresh_token"]},
    )
    assert refreshed.status_code == 200
    assert decode_token(refreshed.json()["access_token"])["ver"] == 2
    assert decode_token(refreshed.json()["refresh_token"])["ver"] == 2
    assert (
        await client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {refreshed.json()['access_token']}"},
        )
    ).status_code == 200


async def test_password_change_removes_all_registered_devices(client):
    registered = await client.post(
        "/api/v1/auth/register",
        json={"email": "rotate-devices@example.com", "password": "password123"},
    )
    old = registered.json()
    authorization = {"Authorization": f"Bearer {old['access_token']}"}

    for token in ("first-device-token", "second-device-token"):
        response = await client.post(
            "/api/v1/notifications/devices",
            headers=authorization,
            json={"token": token, "platform": "ios"},
        )
        assert response.status_code == 201

    assert len(
        (
            await client.get(
                "/api/v1/notifications/devices",
                headers=authorization,
            )
        ).json()
    ) == 2

    response = await client.post(
        "/api/v1/auth/change-password",
        headers=authorization,
        json={"current_password": "password123", "new_password": "replacement456"},
    )

    assert response.status_code == 204
    replacement = await client.post(
        "/api/v1/auth/login",
        json={"email": "rotate-devices@example.com", "password": "replacement456"},
    )
    assert replacement.status_code == 200
    assert (
        await client.get(
            "/api/v1/notifications/devices",
            headers={
                "Authorization": f"Bearer {replacement.json()['access_token']}"
            },
        )
    ).json() == []


async def test_wrong_current_password_does_not_rotate_tokens(client):
    registered = await client.post(
        "/api/v1/auth/register",
        json={"email": "wrong-current@example.com", "password": "password123"},
    )
    tokens = registered.json()

    response = await client.post(
        "/api/v1/auth/change-password",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
        json={"current_password": "wrong-value", "new_password": "replacement456"},
    )

    assert response.status_code == 400
    assert (
        await client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )
    ).status_code == 200


async def test_legacy_tokens_without_version_remain_valid_for_version_one_user(client):
    registered = await client.post(
        "/api/v1/auth/register",
        json={"email": "legacy-token@example.com", "password": "password123"},
    )
    user_id = decode_token(registered.json()["access_token"])["sub"]
    legacy_access = create_access_token(data={"sub": user_id})
    legacy_refresh = create_refresh_token(data={"sub": user_id})

    assert (
        await client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {legacy_access}"},
        )
    ).status_code == 200
    assert (
        await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": legacy_refresh},
        )
    ).status_code == 200


async def test_password_change_rejects_reusing_current_password(client):
    registered = await client.post(
        "/api/v1/auth/register",
        json={"email": "reuse@example.com", "password": "password123"},
    )
    tokens = registered.json()

    response = await client.post(
        "/api/v1/auth/change-password",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
        json={"current_password": "password123", "new_password": "password123"},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "New password must be different"
    assert (
        await client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )
    ).status_code == 200


async def test_password_change_rejects_short_password_fields(client):
    registered = await client.post(
        "/api/v1/auth/register",
        json={"email": "short-password@example.com", "password": "password123"},
    )

    response = await client.post(
        "/api/v1/auth/change-password",
        headers={"Authorization": f"Bearer {registered.json()['access_token']}"},
        json={"current_password": "short", "new_password": "tiny"},
    )

    assert response.status_code == 422


async def test_password_change_rejects_extra_fields(client):
    registered = await client.post(
        "/api/v1/auth/register",
        json={"email": "extra-field@example.com", "password": "password123"},
    )

    response = await client.post(
        "/api/v1/auth/change-password",
        headers={"Authorization": f"Bearer {registered.json()['access_token']}"},
        json={
            "current_password": "password123",
            "new_password": "replacement456",
            "sign_out_other_devices": False,
        },
    )

    assert response.status_code == 422
