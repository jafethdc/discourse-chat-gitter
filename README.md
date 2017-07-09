
## Installation

Add this repository's `git clone` url to your container's `app.yml` file, at the bottom of the `cmd` section:

```yml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - mkdir -p plugins
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/JafethDC/discourse-chat-gitter.git

```

Rebuild your container:

```
cd /var/discourse
git pull
./launcher rebuild app
```
