# ----------------------
# Git Command Aliases
# ----------------------
alias ga='git add'
alias gaa='git add .'
alias gaaa='git add --all'

# ----------------------
# Python Command Aliases
# ----------------------
alias venv='source .venv/Scripts/activate'

# ----------------------
# Dev Profile Alias
# ----------------------
alias pdev='source ~/.bash_profile_dev && ssh_test'
test -f ~/.bash_profile_dev && . ~/.bash_profile_dev

# ----------------------
# Apps Profile Aliases
# ----------------------
alias pbot='source ~/.bash_profile_simplebot'
alias pnvm='source ~/.bash_profile_nvm'
