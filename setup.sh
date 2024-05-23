#!/bin/bash

sudo cp barrier.service /etc/systemd/system/barrier.service
sudo chmod +x /home/eugenio/workspaces/dotfiles/barrier-start.sh
sudo systemctl daemon-reload
sudo systemctl enable barrier.service
sudo systemctl start barrier.service