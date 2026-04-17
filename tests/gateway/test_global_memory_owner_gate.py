from gateway.run import GatewayRunner


def test_resolve_effective_agent_user_id_normal_mode_keeps_user():
    user_id, err = GatewayRunner._resolve_effective_agent_user_id(
        "8259215216",
        global_memory_requested=False,
        owner_id="8259215216",
    )
    assert err is None
    assert user_id == "8259215216"


def test_resolve_effective_agent_user_id_global_mode_owner_ok_returns_none():
    user_id, err = GatewayRunner._resolve_effective_agent_user_id(
        "8259215216",
        global_memory_requested=True,
        owner_id="8259215216",
    )
    assert err is None
    assert user_id is None


def test_resolve_effective_agent_user_id_global_mode_requires_owner_config():
    user_id, err = GatewayRunner._resolve_effective_agent_user_id(
        "8259215216",
        global_memory_requested=True,
        owner_id="",
    )
    assert user_id == "8259215216"
    assert err is not None
    assert "GLOBAL_MEMORY_OWNER_ID" in err


def test_resolve_effective_agent_user_id_global_mode_rejects_non_owner():
    user_id, err = GatewayRunner._resolve_effective_agent_user_id(
        "12345",
        global_memory_requested=True,
        owner_id="8259215216",
    )
    assert user_id == "12345"
    assert err == "❌ /gmem is owner-only."
