# mkCronJob — reusable factory for Hermes cron-job registration.
#
# Each call returns an attrset that the caller mkMerge's into `config`:
#   { activationScript, systemdService, restartTriggers }
#
# The pattern: a Python gate script runs every tick. If it prints nothing the
# agent stays asleep (zero tokens). When it prints output, the agent wakes,
# executes the handle prompt, and delivers the result via `deliver`.
{
  config,
  lib,
  pkgs,
}:
{
  name,
  interval,
  deliver,
  script,
  scriptName,
  prompt,
  promptName ? "${name}-handle-prompt.md",
  skills ? [ ],
  jobName ? name,
}:
let
  containerName = "hermes-agent";
  containerHermes = "/data/current-package/bin/hermes";
  hermesStateDir = config.services.hermes-agent.stateDir;
  hermesUser = config.services.hermes-agent.user;
  hermesGroup = config.services.hermes-agent.group;
  promptContainerPath = "/data/.hermes/${promptName}";

  skillArgs = lib.concatMapStringsSep " " (s: "--skill ${lib.escapeShellArg s}") skills;

  registerScript = pkgs.writeShellScript "hermes-${name}-register" ''
    set -euo pipefail

    hermes() { ${pkgs.docker}/bin/docker exec ${containerName} ${containerHermes} "$@"; }

    ready=
    for _ in $(seq 1 60); do
      if ${pkgs.docker}/bin/docker exec ${containerName} test -x ${containerHermes} 2>/dev/null; then
        ready=1
        break
      fi
      sleep 2
    done
    if [ -z "$ready" ]; then
      echo "hermes-agent container not ready after 120s; skipping cron registration for ${name}" >&2
      exit 1
    fi

    prompt="$(${pkgs.docker}/bin/docker exec ${containerName} cat ${promptContainerPath})"

    hermes cron remove ${lib.escapeShellArg jobName} >/dev/null 2>&1 || true
    hermes cron create ${lib.escapeShellArg interval} "$prompt" \
      --name ${lib.escapeShellArg jobName} \
      --script ${lib.escapeShellArg scriptName} \
      ${skillArgs} \
      --deliver ${lib.escapeShellArg deliver}

    echo "Registered Hermes cron job '${jobName}' (${interval}, deliver=${deliver})"
  '';
in
{
  activationScript = lib.stringAfter [ "hermes-agent-setup" ] ''
    mkdir -p ${hermesStateDir}/.hermes/scripts
    install -o ${hermesUser} -g ${hermesGroup} -m 0640 \
      ${script} ${hermesStateDir}/.hermes/scripts/${scriptName}
    install -o ${hermesUser} -g ${hermesGroup} -m 0640 \
      ${prompt} ${hermesStateDir}/.hermes/${promptName}
  '';

  systemdService = {
    description = "Register Hermes cron job: ${name}";
    after = [ "hermes-agent.service" ];
    requires = [ "hermes-agent.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.docker
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = registerScript;
    };
    restartTriggers = [
      script
      prompt
      registerScript
    ];
  };
}
