<div align="center">
  <h1><img alt="GOAD (Game Of Active Directory)" src="./docs/mkdocs/docs/img/logo_GOAD3.png"></h1>
  <br>
</div>

**GOAD (v3)**

:bookmark: Documentation : [https://orange-cyberdefense.github.io/GOAD/](https://orange-cyberdefense.github.io/GOAD/)

## Description
GOAD is a pentest active directory LAB project.
The purpose of this lab is to give pentesters a vulnerable Active directory environment ready to use to practice usual attack techniques.

> [!CAUTION]
> This lab is extremely vulnerable, do not reuse recipe to build your environment and do not deploy this environment on internet without isolation (this is a recommendation, use it as your own risk).<br>
> This repository was build for pentest practice.

![goad_screenshot](./docs/img/goad_screenshot.png)

## Licenses
This lab use free Windows VM only (180 days). After that delay enter a license on each server or rebuild all the lab (may be it's time for an update ;))

## OCI Management Agent (Post-Provision)

This repository includes an external workflow to install OCI Management Agent on both Windows and Linux VMs without changing the default deployment flow.

1. Prepare variables (PAR URLs for agent packages and install key) and run:

```bash
./scripts/install_oci_management_agents.sh --instance <instance_id> \
  --windows-zip-url "<windows_zip_url>" \
  --linux-zip-url "<linux_package_url_zip_or_rpm>" \
  --install-key-id "<ocid1.managementagentinstallkey...>"
```

2. You can also generate/update only the override vars file and run later:

```bash
./scripts/install_oci_management_agents.sh --prepare-only
```

The wrapper writes overrides to `workspace/oci_management_agent_vars.yml` and then calls:

```bash
python3 goad.py -t install -r oci_management_agent.yml [-i <instance_id>]
```

For already-provisioned projects where you want direct inventory mode:

```bash
./scripts/install_oci_management_agents.sh \
  --inventory ad/GOAD/providers/oci/inventory \
  --global-inventory globalsettings.ini \
  --windows-zip-url "<windows_zip_url>" \
  --linux-zip-url "<linux_package_url_zip_or_rpm>" \
  --install-key-id "<ocid1.managementagentinstallkey...>"
```

## Available labs

- GOAD Lab family and extensions overview
<div align="center">
<img alt="GOAD" width="800" src="./docs/img/diagram-GOADv3-full.png">
</div>

- [GOAD](https://orange-cyberdefense.github.io/GOAD/labs/GOAD/) : 5 vms, 2 forests, 3 domains (full goad lab)
<div align="center">
<img alt="GOAD" width="800" src="./docs/img/GOAD_schema.png">
</div>

- [GOAD-Light](https://orange-cyberdefense.github.io/GOAD/labs/GOAD-Light/) : 3 vms, 1 forest, 2 domains (smaller goad lab for those with a smaller pc)
<div align="center">
<img alt="GOAD Light" width="600" src="./docs/img/GOAD-Light_schema.png">
</div>

- [MINILAB](https://orange-cyberdefense.github.io/GOAD/labs/MINILAB/): 2 vms, 1 forest, 1 domain (basic lab with one DC (windows server 2019) and one Workstation (windows 10))

- [SCCM](https://orange-cyberdefense.github.io/GOAD/labs/SCCM/) : 4 vms, 1 forest, 1 domain, with microsoft configuration manager installed
<div align="center">
<img alt="SCCM" width="600" src="./docs/img/SCCMLAB_overview.png">
</div>

- [NHA](https://orange-cyberdefense.github.io/GOAD/labs/NHA/) : A challenge with 5 vms and 2 domains. no schema provided, you will have to find out how break it.
