.DEFAULT_GOAL := help

COMPOSE := docker compose
KALI := $(COMPOSE) exec -T --user kali kali

.PHONY: help up down reset recon brute hydra sqli alerts block unblock validate

help:
	@printf '%s\n' \
	  'make up       Start the isolated lab.' \
	  'make reset    Reset DVWA data and select the Low security level.' \
	  'make recon    Run the authorised service discovery from Kali.' \
	  'make brute    Replay the short DVWA login scenario from Kali.' \
	  'make hydra    Replay the same short DVWA login scenario with Hydra.' \
	  'make sqli     Replay the controlled DVWA SQL injection scenario.' \
	  'make alerts   Follow Suricata alerts.' \
	  'make block    Isolate Kali at the gateway after validating an alert.' \
	  'make unblock  Restore the baseline gateway policy.' \
	  'make validate Validate Compose and the loaded Suricata rules.'

up:
	$(COMPOSE) up -d --build --wait

down:
	$(COMPOSE) down

reset:
	$(KALI) /opt/scenarios/00-init-dvwa.sh

recon:
	$(KALI) /opt/scenarios/01-recon.sh

brute:
	$(KALI) /opt/scenarios/02-bruteforce.sh

hydra:
	$(KALI) /opt/scenarios/04-hydra.sh

sqli:
	$(KALI) /opt/scenarios/03-sqli.sh

alerts:
	tail -F evidence/suricata/fast.log

block:
	$(COMPOSE) exec -T gateway /opt/lab/firewall/block-kali.sh

unblock:
	$(COMPOSE) exec -T gateway /opt/lab/firewall/unblock-kali.sh

validate:
	$(COMPOSE) config --quiet
	$(COMPOSE) exec -T gateway suricata -T -c /etc/suricata/suricata.yaml -S /etc/suricata/local-rules/local.rules
