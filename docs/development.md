# Development

## Internal Configurations

The following configurations are set automatically by *Gantry* internally. User usually does not need to touch them.

| Environment Variable  | Default | Description |
|-----------------------|---------|-------------|
| GANTRY_LIB_DIR                | | To tell *entrypoint.sh* where to load all libraries. |
| GANTRY_SERVICES_SELF          | | This is optional. When running as a docker service, *Gantry* will try to find the service name of itself automatically, and update itself firstly. The manifest inspection will be always performed on the *Gantry* service to avoid an infinity loop of updating itself. This can be used to ask *Gantry* to update another service firstly. |
| GANTRY_IMAGES_TO_REMOVE       | | A space separated list of images passing from the updater to image remover. |
| GANTRY_CLEANUP_IMAGES_REMOVER | `ghcr.io/shizunge/gantry` | *Gantry* launches a global-job to remove images on all hosts. When *Gantry* runs as a service, it will firstly try to use the same image as the service itself. This is only used to specify image used by the global-job when *Gantry* does not run as a service. |
