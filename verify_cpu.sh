#!/usr/bin/env bash
# 在主機執行；motor-week03 必須已由 run.sh 啟動。
set -euo pipefail
lab_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
evidence_dir="${EVIDENCE_DIR:-$lab_dir/evidence}"
mkdir -p "$evidence_dir"
docker exec motor-week03 bash -lc 'source /etc/ros_env.sh; week03-check' \
  | tee "$evidence_dir/week03-check.txt"
docker exec motor-week03 bash -lc 'source /etc/ros_env.sh; id; printenv ROS_DISTRO ROS_DOMAIN_ID ROS_LOCALHOST_ONLY; echo week03 > ~/ros2_ws/proof.txt' \
  | tee "$evidence_dir/runtime.txt"
test "$(cat "$lab_dir/ros2_ws/proof.txt")" = week03
test "$(stat -c %u "$lab_dir/ros2_ws/proof.txt")" = "$(id -u)"
stat -c '%U %u %n' "$lab_dir/ros2_ws/proof.txt" | tee "$evidence_dir/mount-check.txt"
docker exec -i motor-week03 bash <<'INNER' | tee "$evidence_dir/ros-communication.txt"
set -eo pipefail
source /etc/ros_env.sh
set -u
setsid ros2 run demo_nodes_cpp talker >/tmp/week03-talker.txt 2>&1 &
talker_pid=$!
trap 'kill -INT -- "-$talker_pid" 2>/dev/null || true; wait "$talker_pid" 2>/dev/null || true' EXIT
set +e
timeout --signal=INT 12 ros2 run demo_nodes_py listener >/tmp/week03-listener.txt 2>&1
result=$?
set -e
if [ "$result" != 0 ] && [ "$result" != 124 ]; then cat /tmp/week03-listener.txt; exit "$result"; fi
cat /tmp/week03-listener.txt
count=$(grep -c 'I heard:.*Hello World:' /tmp/week03-listener.txt || true)
test "$count" -ge 3
echo "PASS: listener received $count messages."
INNER
