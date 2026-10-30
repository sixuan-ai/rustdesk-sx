use hbb_common::{
    config::RELAY_PORT,
    futures::{stream, StreamExt},
    socket_client::{check_port, connect_tcp_local},
    tokio,
};
use std::time::Duration;

pub(super) fn endpoint(id: &str) -> Option<String> {
    if hbb_common::is_ip_str(id) {
        Some(check_port(id, RELAY_PORT + 1))
    } else if hbb_common::is_domain_port_str(id) {
        Some(id.to_owned())
    } else {
        None
    }
}

async fn reachable(address: String) -> bool {
    // Match the real direct connection's transport, but do not authenticate,
    // request capture, send input or claim that an open port is a RustDesk login.
    matches!(
        tokio::time::timeout(
            Duration::from_millis(1500),
            connect_tcp_local(address, None, 1500)
        )
        .await,
        Ok(Ok(_))
    )
}

pub(super) async fn query(ids: Vec<String>) -> (Vec<String>, Vec<String>) {
    let (direct, server): (Vec<_>, Vec<_>) = ids.into_iter().partition(|id| endpoint(id).is_some());
    let direct_query = stream::iter(direct.into_iter().map(|id| async move {
        let online = match endpoint(&id) {
            Some(address) => reachable(address).await,
            None => false,
        };
        (id, online)
    }))
    .buffer_unordered(8)
    .collect::<Vec<_>>();
    let server_query = async {
        if server.is_empty() {
            return (vec![], vec![]);
        }
        if base::config::is_direct_only() {
            return (vec![], server);
        }
        let timeout = Duration::from_secs(3);
        // An unavailable ID server must not hold back direct-address results.
        match tokio::time::timeout(timeout, super::query_online_states_(&server, timeout)).await {
            Ok(Ok(states)) => states,
            _ => (vec![], server),
        }
    };
    let (states, (mut online, mut unconfirmed)) = tokio::join!(direct_query, server_query);
    for (id, reachable) in states {
        if reachable {
            online.push(id);
        } else {
            unconfirmed.push(id);
        }
    }
    (online, unconfirmed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn direct_addresses_use_the_connection_port_and_ids_stay_server_based() {
        assert_eq!(endpoint("100.89.0.1").as_deref(), Some("100.89.0.1:21118"));
        assert_eq!(
            endpoint("100.89.0.1:22000").as_deref(),
            Some("100.89.0.1:22000")
        );
        assert_eq!(
            endpoint("[2001:db8::1]:22000").as_deref(),
            Some("[2001:db8::1]:22000")
        );
        assert_eq!(
            endpoint("omen.example.com:22000").as_deref(),
            Some("omen.example.com:22000")
        );
        assert_eq!(endpoint("123456789"), None);
        assert_eq!(endpoint("123456789@id.example.com"), None);
    }

    #[tokio::test]
    async fn direct_status_tracks_an_open_port_then_a_closed_port_without_an_id_server() {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = listener.local_addr().unwrap().to_string();
        assert_eq!(
            query(vec![address.clone()]).await,
            (vec![address.clone()], vec![])
        );
        drop(listener);
        assert_eq!(query(vec![address.clone()]).await, (vec![], vec![address]));
    }
}
