use std::{env, process};

use hbb_common::{
    config::{Config, LanPeers, LocalConfig, PeerConfig},
    tokio,
};
use serde_json::{json, Map, Value};

use crate::ipc;

const EXIT_FAILED: i32 = 1;
const EXIT_USAGE: i32 = 2;

enum CliError {
    Usage(String),
    Failed(String),
}

type CliResult = Result<(), CliError>;

struct PeerRow {
    id: String,
    alias: String,
    hostname: String,
    username: String,
    platform: String,
    last_connected: Option<String>,
    favorite: bool,
    online: Option<bool>,
}

pub fn is_cli_invocation() -> bool {
    env::args().nth(1).as_deref() == Some("--cli")
}

pub fn run() -> ! {
    let args: Vec<String> = env::args().skip(2).collect();
    let code = match execute(&args) {
        Ok(()) => 0,
        Err(CliError::Usage(message)) => {
            eprintln!("error: {message}\n");
            print_help();
            EXIT_USAGE
        }
        Err(CliError::Failed(message)) => {
            eprintln!("error: {message}");
            EXIT_FAILED
        }
    };
    process::exit(code)
}

fn execute(raw: &[String]) -> CliResult {
    let mut json_output = false;
    let mut args = Vec::new();
    for arg in raw {
        match arg.as_str() {
            "--json" => json_output = true,
            "--help" | "-h" => {
                print_help();
                return Ok(());
            }
            _ => args.push(arg.clone()),
        }
    }
    let Some(command) = args.first() else {
        print_help();
        return Ok(());
    };
    let rest = &args[1..];
    match command.as_str() {
        "help" => {
            print_help();
            Ok(())
        }
        "status" => command_status(rest, json_output),
        "id" => command_id(rest, json_output),
        "password" => command_password(rest, json_output),
        "peers" => command_peers(rest, json_output),
        "connect" => command_session("--connect", "connect", rest, json_output),
        "file-transfer" => command_session("--file-transfer", "file-transfer", rest, json_output),
        "port-forward" => command_session("--port-forward", "port-forward", rest, json_output),
        "terminal" => command_session("--terminal", "terminal", rest, json_output),
        "camera" => command_session("--view-camera", "camera", rest, json_output),
        "rdp" => command_session("--rdp", "rdp", rest, json_output),
        "option" => command_option(rest, json_output),
        other => Err(CliError::Usage(format!("unknown command '{other}'"))),
    }
}

fn command_status(args: &[String], json_output: bool) -> CliResult {
    expect_no_args(args)?;
    let live_id = ipc::get_config("id")
        .ok()
        .flatten()
        .filter(|id| !id.is_empty());
    let running = live_id.is_some();
    let id = live_id.unwrap_or_else(Config::get_id);
    let permanent_password_set = ipc::get_config("permanent-password-set")
        .ok()
        .flatten()
        .as_deref()
        == Some("Y");
    let online_state = if running { online_state() } else { None };
    let (online, latency_ms, key_confirmed) = match online_state {
        Some((latency, confirmed)) => (
            Some(latency > 0),
            Some(latency.max(0) / 1_000),
            Some(confirmed),
        ),
        None => (None, None, None),
    };
    let rendezvous_server = Config::get_rendezvous_server();
    #[cfg(target_os = "macos")]
    let daemon_installed = Some(crate::ui_interface::is_installed_daemon(false));
    #[cfg(not(target_os = "macos"))]
    let daemon_installed = None;

    if json_output {
        print_json(&json!({
            "app_running": running,
            "id": id,
            "version": crate::VERSION,
            "build_date": crate::BUILD_DATE,
            "platform": env::consts::OS,
            "app_name": crate::get_app_name(),
            "permanent_password_set": permanent_password_set,
            "online": online,
            "latency_ms": latency_ms,
            "key_confirmed": key_confirmed,
            "rendezvous_server": rendezvous_server,
            "daemon_installed": daemon_installed,
        }));
    } else {
        println!(
            "App: {} {} ({})",
            crate::get_app_name(),
            crate::VERSION,
            if running { "running" } else { "not running" }
        );
        println!("ID: {id}");
        match online {
            Some(true) => println!("Online: yes ({} ms)", latency_ms.unwrap_or_default()),
            Some(false) => println!("Online: no"),
            None => println!("Online: unknown"),
        }
        println!(
            "Permanent password: {}",
            if permanent_password_set {
                "set"
            } else {
                "not set"
            }
        );
        println!(
            "Rendezvous server: {}",
            if rendezvous_server.is_empty() {
                "unknown"
            } else {
                rendezvous_server.as_str()
            }
        );
        println!(
            "Background service: {}",
            match daemon_installed {
                Some(true) => "installed",
                Some(false) => "not installed",
                None => "unknown",
            }
        );
    }
    Ok(())
}

fn command_id(args: &[String], json_output: bool) -> CliResult {
    expect_no_args(args)?;
    let id = ipc::get_id();
    if json_output {
        print_json(&json!({ "id": id }));
    } else {
        println!("{id}");
    }
    Ok(())
}

fn command_password(args: &[String], json_output: bool) -> CliResult {
    expect_no_args(args)?;
    if ipc::get_config("id").ok().flatten().is_none() {
        return Err(CliError::Failed(
            "RustDesk is not running; start the app before reading the temporary password"
                .to_owned(),
        ));
    }
    let password = ipc::get_config("temporary-password")
        .map_err(|err| CliError::Failed(format!("cannot reach RustDesk: {err}")))?
        .ok_or_else(|| CliError::Failed("RustDesk did not return a password".to_owned()))?;
    if json_output {
        print_json(&json!({ "password": password }));
    } else {
        println!("{password}");
    }
    Ok(())
}

fn command_peers(args: &[String], json_output: bool) -> CliResult {
    let mut lan = false;
    let mut query = None;
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--lan" => lan = true,
            "--query" => {
                i += 1;
                query = Some(
                    args.get(i)
                        .cloned()
                        .ok_or_else(|| CliError::Usage("--query needs a value".to_owned()))?,
                );
            }
            arg if !arg.starts_with('-') && query.is_none() => query = Some(arg.to_owned()),
            arg => {
                return Err(CliError::Usage(format!(
                    "unexpected argument '{arg}' for peers"
                )))
            }
        }
        i += 1;
    }
    let query = query.map(|value| value.to_lowercase());
    let peers = if lan {
        lan_peers(query.as_deref())
    } else {
        known_peers(query.as_deref())
    };

    if json_output {
        let peers: Vec<Value> = peers
            .iter()
            .map(|peer| {
                json!({
                    "id": peer.id,
                    "alias": peer.alias,
                    "hostname": peer.hostname,
                    "username": peer.username,
                    "platform": peer.platform,
                    "last_connected": peer.last_connected,
                    "favorite": peer.favorite,
                    "online": peer.online,
                })
            })
            .collect();
        print_json(&json!({
            "source": if lan { "lan" } else { "known" },
            "count": peers.len(),
            "peers": peers,
        }));
    } else if peers.is_empty() {
        println!("No devices found");
    } else {
        println!(
            "{:<16} {:<24} {:<24} {:<10} {}",
            "ID", "ALIAS", "HOSTNAME", "PLATFORM", "LAST CONNECTED"
        );
        for peer in peers {
            println!(
                "{:<16} {:<24} {:<24} {:<10} {}",
                peer.id,
                or_dash(&peer.alias),
                or_dash(&peer.hostname),
                or_dash(&peer.platform),
                peer.last_connected
                    .or_else(|| peer.online.map(|online| if online {
                        "online (LAN)".to_owned()
                    } else {
                        "offline (LAN)".to_owned()
                    }))
                    .unwrap_or_else(|| "-".to_owned())
            );
        }
    }
    Ok(())
}

fn known_peers(query: Option<&str>) -> Vec<PeerRow> {
    let favorites = LocalConfig::get_fav();
    let mut peers: Vec<(std::time::SystemTime, PeerRow)> = PeerConfig::peers(None)
        .into_iter()
        .filter_map(|(id, modified, config)| {
            let row = PeerRow {
                alias: config.options.get("alias").cloned().unwrap_or_default(),
                hostname: config.info.hostname,
                username: config.info.username,
                platform: config.info.platform,
                last_connected: Some(format_time(modified)),
                favorite: favorites.contains(&id),
                online: None,
                id,
            };
            matches_query(&row, query).then_some((modified, row))
        })
        .collect();
    peers.sort_by(|a, b| b.0.cmp(&a.0));
    peers.into_iter().map(|(_, row)| row).collect()
}

fn lan_peers(query: Option<&str>) -> Vec<PeerRow> {
    let favorites = LocalConfig::get_fav();
    let mut peers: Vec<PeerRow> = LanPeers::load()
        .peers
        .into_iter()
        .filter_map(|peer| {
            let favorite = favorites.contains(&peer.id);
            let row = PeerRow {
                id: peer.id,
                alias: String::new(),
                hostname: peer.hostname,
                username: peer.username,
                platform: peer.platform,
                last_connected: None,
                favorite,
                online: Some(peer.online),
            };
            matches_query(&row, query).then_some(row)
        })
        .collect();
    peers.sort_by(|a, b| a.id.cmp(&b.id));
    peers
}

fn matches_query(peer: &PeerRow, query: Option<&str>) -> bool {
    let Some(query) = query else {
        return true;
    };
    [
        &peer.id,
        &peer.alias,
        &peer.hostname,
        &peer.username,
        &peer.platform,
    ]
    .iter()
    .any(|value| value.to_lowercase().contains(query))
}

fn command_session(flag: &str, label: &str, args: &[String], json_output: bool) -> CliResult {
    let mut id = None;
    let mut password = None;
    let mut relay = false;
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--password" => {
                i += 1;
                password = Some(
                    args.get(i)
                        .cloned()
                        .ok_or_else(|| CliError::Usage("--password needs a value".to_owned()))?,
                );
            }
            "--relay" => relay = true,
            arg if !arg.starts_with('-') => id = Some(arg.to_owned()),
            arg => {
                return Err(CliError::Usage(format!(
                    "unexpected argument '{arg}' for {label}"
                )))
            }
        }
        i += 1;
    }
    let id = id.ok_or_else(|| CliError::Usage(format!("{label} needs a remote ID")))?;

    let mut spawn_args = vec![flag.to_owned(), id.clone()];
    if let Some(password) = &password {
        spawn_args.push("--password".to_owned());
        spawn_args.push(password.clone());
    }
    if relay {
        spawn_args.push("--relay".to_owned());
    }
    let child = crate::run_me(spawn_args)
        .map_err(|err| CliError::Failed(format!("failed to start {label}: {err}")))?;
    if json_output {
        print_json(&json!({
            "dispatched": true,
            "type": label,
            "id": id,
            "relay": relay,
            "pid": child.id(),
        }));
    } else {
        println!("Requested {label} session with {id}");
    }
    Ok(())
}

fn command_option(args: &[String], json_output: bool) -> CliResult {
    let Some(subcommand) = args.first() else {
        return Err(CliError::Usage(
            "option needs one of: list, get, set, unset".to_owned(),
        ));
    };
    match subcommand.as_str() {
        "list" => {
            expect_no_args(&args[1..])?;
            let options = ipc::get_options();
            if json_output {
                let mut map = Map::new();
                let mut keys: Vec<_> = options.keys().cloned().collect();
                keys.sort();
                for key in keys {
                    if let Some(value) = options.get(&key) {
                        map.insert(key, Value::String(value.clone()));
                    }
                }
                print_json(&json!({ "count": map.len(), "options": map }));
            } else {
                let mut keys: Vec<_> = options.keys().collect();
                keys.sort();
                for key in keys {
                    if let Some(value) = options.get(key) {
                        println!("{key}={value}");
                    }
                }
            }
        }
        "get" => {
            let key = args
                .get(1)
                .ok_or_else(|| CliError::Usage("option get needs a key".to_owned()))?;
            expect_no_args(&args[2..])?;
            let value = ipc::get_options().get(key).cloned().unwrap_or_default();
            if json_output {
                print_json(&json!({ "key": key, "value": value }));
            } else {
                println!("{value}");
            }
        }
        "set" => {
            let key = args
                .get(1)
                .ok_or_else(|| CliError::Usage("option set needs a key".to_owned()))?;
            let value = args
                .get(2)
                .ok_or_else(|| CliError::Usage("option set needs a value".to_owned()))?;
            expect_no_args(&args[3..])?;
            let mut options = ipc::get_options();
            options.insert(key.clone(), value.clone());
            ipc::set_options(options)
                .map_err(|err| CliError::Failed(format!("failed to update option: {err}")))?;
            if json_output {
                print_json(&json!({ "ok": true, "key": key, "value": value }));
            } else {
                println!("{key}={value}");
            }
        }
        "unset" => {
            let key = args
                .get(1)
                .ok_or_else(|| CliError::Usage("option unset needs a key".to_owned()))?;
            expect_no_args(&args[2..])?;
            let mut options = ipc::get_options();
            options.remove(key);
            ipc::set_options(options)
                .map_err(|err| CliError::Failed(format!("failed to update option: {err}")))?;
            if json_output {
                print_json(&json!({ "ok": true, "key": key, "unset": true }));
            } else {
                println!("Unset {key}");
            }
        }
        other => return Err(CliError::Usage(format!("unknown option command '{other}'"))),
    }
    Ok(())
}

fn online_state() -> Option<(i64, bool)> {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .ok()?;
    runtime.block_on(async {
        let mut connection = ipc::connect(1_000, "").await.ok()?;
        connection.send(&ipc::Data::OnlineStatus(None)).await.ok()?;
        match connection.next_timeout(1_000).await.ok()? {
            Some(ipc::Data::OnlineStatus(state)) => state,
            _ => None,
        }
    })
}

fn format_time(time: std::time::SystemTime) -> String {
    chrono::DateTime::<chrono::Local>::from(time)
        .to_rfc3339_opts(chrono::SecondsFormat::Secs, false)
}

fn or_dash(value: &str) -> &str {
    if value.is_empty() {
        "-"
    } else {
        value
    }
}

fn expect_no_args(args: &[String]) -> CliResult {
    match args.first() {
        Some(arg) => Err(CliError::Usage(format!("unexpected argument '{arg}'"))),
        None => Ok(()),
    }
}

fn print_json(value: &Value) {
    println!("{value}");
}

fn print_help() {
    println!(
        "\
{} CLI {}

Usage: {} --cli <command> [options]

Commands:
  status [--json]                          Show app, ID, connectivity and service state
  id [--json]                              Print this device's ID
  password [--json]                        Print the temporary password (app must be running)
  peers [query] [--lan] [--json]           List known peers or cached LAN discoveries
  connect <id> [--password <pw>] [--relay] Open a remote desktop session
  file-transfer <id> [--password <pw>]     Open a file transfer session
  port-forward <id> [--password <pw>]      Open a port forwarding session
  terminal <id> [--password <pw>]          Open a terminal session
  camera <id> [--password <pw>]            View a remote camera
  rdp <id> [--password <pw>]               Open an RDP session
  option list                              List all options
  option get <key>                         Read one option
  option set <key> <value>                 Write one option
  option unset <key>                       Remove one option

Options:
  --json    Machine-readable compact JSON
  --help    Show this help

Exit codes: 0 success, 1 runtime failure, 2 usage error",
        crate::get_app_name(),
        crate::VERSION,
        crate::get_app_name(),
    );
}
