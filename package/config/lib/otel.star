load("@ytt:data", "data")
load("@ytt:sha256", "sha256")
load("@ytt:struct", "struct")
load("@ytt:yaml", "yaml")

# ###########
# OPERATOR
# ###########

# The names of the operator resources in the upstream manifest.
deployment = "opentelemetry-operator-controller-manager"
certificate = "opentelemetry-operator-serving-cert"
webhook_service = "opentelemetry-operator-webhook-service"
image_pull_secret_name = "canonical-registry-credentials"

# The ConfigMap holding the operator configuration file, and where it's mounted.
config_name = "opentelemetry-operator-config"
config_dir = "/conf"
config_file = "config.yaml"

# The labels selecting the operator Pods, as in the upstream Deployment.
selector = {"app.kubernetes.io/name": "opentelemetry-operator", "control-plane": "controller-manager"}

# ###########
# CONFIGURATION
# ###########

# The configuration file keys enabling the auto-instrumentation of each language.
# They're not consistent with the names of the flags and environment variables.
# See: https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/reference/configuration.md
_instrumentation_keys = {
  "apache_httpd": "enable-apache-httpd-instrumentation",
  "dotnet": "enable-dot-net-auto-instrumentation",
  "go": "enable-go-auto-instrumentation",
  "java": "enable-java-auto-instrumentation",
  "nginx": "enable-nginx-auto-instrumentation",
  "nodejs": "enable-node-js-auto-instrumentation",
  "php": "enable-php-auto-instrumentation",
  "python": "enable-python-auto-instrumentation",
  "ruby": "enable-ruby-auto-instrumentation",
}

# The upstream environment variables overriding the configuration file. Their values are moved to the file.
config_env_vars = ["ENABLE_LEADER_ELECTION", "ENABLE_NGINX_AUTO_INSTRUMENTATION", "METRICS_ADDR", "METRICS_SECURE"]

# The operator configuration computed from the package values. `config` is merged on top of it, key by key.
# The operator reads it from a file, at startup, and applies the environment variables and the flags on top.
# See: https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/reference/configuration.md
def operator_config():
  values = data.values
  config = {
    "enable-leader-election": True,
    "metrics-addr": ":8443",
    "metrics-secure": True,
    "enable-multi-instrumentation": values.auto_instrumentation.multi_instrumentation,
  }
  for language, key in _instrumentation_keys.items():
    config[key] = getattr(values.auto_instrumentation, language)
  end

  for name, value in struct.decode(values.config).items():
    config[name] = value
  end
  return {name: value for name, value in config.items() if value != None}
end

def operator_config_file():
  return yaml.encode(operator_config())
end

# The checksum of the operator configuration, which the operator only reads at startup.
# It's added to the Pod template, so that a change rolls out the operator.
def operator_config_checksum():
  return sha256.sum(operator_config_file())
end

# The port of the metrics endpoint, and whether it's served over HTTPS, as configured.
def metrics_port():
  return operator_config()["metrics-addr"].rpartition(":")[2]
end

def metrics_secure():
  return operator_config().get("metrics-secure", True) in [True, "true"]
end

# ###########
# FLAGS
# ###########

# The flags computed from the package values. `args` is merged on top of them.
def operator_args():
  args = {
    "config-file": config_dir + "/" + config_file,
    "zap-log-level": data.values.observability.logging.level,
    "zap-encoder": "json",
  }
  for name, value in struct.decode(data.values.args).items():
    args[name.lstrip("-")] = value
  end
  return args
end

def _format(value):
  if type(value) == "bool":
    return "true" if value else "false"
  end
  return str(value)
end

# Merges the given flags into the upstream ones, keeping their order. New flags are appended,
# and flags set to null are removed. The arguments that aren't flags, and the flags without a value, are kept as they are.
def _merge_args(upstream, overrides):
  commands = [arg for arg in upstream if not arg.startswith("-")]
  flags = {}
  for arg in upstream:
    if arg.startswith("-"):
      name, separator, value = arg.lstrip("-").partition("=")
      flags[name] = value if separator else None
    end
  end
  for name, value in overrides.items():
    if value == None:
      flags.pop(name, None)
    else:
      flags[name] = _format(value)
    end
  end
  return commands + ["--" + name if value == None else "--" + name + "=" + value for name, value in flags.items()]
end

# The `via` function of the overlay replacing the upstream container args.
def args_merger(overrides):
  return lambda left, _: _merge_args(left, overrides)
end

# The `via` function of the overlay removing the upstream environment variables that override the configuration file.
def env_filter():
  return lambda left, _: [env for env in left if env["name"] not in config_env_vars]
end
