/// Coarse network profile used to split traffic statistics.
enum NetworkProfile { wifi, cellular, unknown }

/// Reason a traffic-statistics subscription fired.
enum NetworkPolicyChange { connected, disconnected, profileChanged }
