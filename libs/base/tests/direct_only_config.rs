#![cfg(target_os = "linux")]

use hbb_common::config::Config;

#[test]
fn direct_only_is_opt_in_and_preserves_direct_access_and_account_options() {
    // An integration-test binary has its own Config globals. Isolate disk writes
    // as well, so this test never changes a developer's connection settings.
    let root = std::env::temp_dir().join(format!("sx-direct-only-test-{}", std::process::id()));
    std::fs::create_dir_all(&root).unwrap();
    std::env::set_var("XDG_CONFIG_HOME", &root);
    assert!(!base::config::is_direct_only());
    Config::set_option("direct-server".into(), "Y".into());
    Config::set_option("api-server".into(), "https://accounts.example.com".into());
    Config::set_option(base::config::keys::OPTION_DIRECT_ONLY.into(), "Y".into());
    assert!(base::config::is_direct_only());
    assert_eq!(Config::get_option("direct-server"), "Y");
    assert_eq!(Config::get_option("api-server"), "https://accounts.example.com");
    Config::set_option(base::config::keys::OPTION_DIRECT_ONLY.into(), "N".into());
    assert!(!base::config::is_direct_only());
    std::fs::remove_dir_all(root).unwrap();
}
