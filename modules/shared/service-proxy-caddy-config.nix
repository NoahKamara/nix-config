{ pkgs }:
pkgs.writeText "service-proxy-caddy.json" ''
  {
    "admin": {
      "listen": "127.0.0.1:2019"
    },
    "apps": {
      "http": {
        "servers": {
          "srv0": {
            "listen": [
              ":8080"
            ],
            "routes": []
          }
        }
      }
    }
  }
''
