#!/bin/bash

set -eu

ESC=$(printf '\033')
readonly ESC
readonly RESET="${ESC}[0m"
readonly BOLD="${ESC}[1m"
readonly FAINT="${ESC}[2m"
readonly RED="${ESC}[31m"

function print () {
  echo "$FAINT==>$RESET $BOLD$1$RESET"
}

# 1. check
print 'Checking your platform...'
if [ "$(uname)" = 'Darwin' ]; then
  OS='Mac'
elif [ "$(uname -s | cut -c 1-5)" = 'Linux' ] && type apt > /dev/null 2>&1; then
  OS='Linux'
else
  echo "${RED}Error:${RESET} Your platform ($(uname -a)) is not supported." 1>&2
  exit 1
fi
echo "Your platfrom is $OS"
echo ''

if [ "$OS" = 'Linux' ]; then
  print 'Updating package list...'
  if [ ${EUID:-${UID}} = 0 ]; then
    apt update
    if ! type sudo > /dev/null 2>&1; then
      print 'Installing sudo...'
      apt install sudo
      echo ''
    fi
  else
    sudo apt update
  fi
  echo ''
fi

# 2. homebrew
if [ "$OS" = 'Linux' ]; then
  print 'Installing packages required for homebrew...'
  sudo apt install -y curl git
  echo ''
fi

print 'Installing Homebrew...'
if [ "$OS" = 'Linux' ]; then
  if [ -e /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [ -e $HOME/.linuxbrew/bin/brew ]; then
    eval "$($HOME/.linuxbrew/bin/brew shellenv)"
  fi
fi
if type brew > /dev/null 2>&1; then
  echo 'Homebrew is already installed'
else
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ "$OS" = 'Linux' ]; then
    if [ -e /home/linuxbrew/.linuxbrew/bin/brew ]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [ -e $HOME/.linuxbrew/bin/brew ]; then
      eval "$($HOME/.linuxbrew/bin/brew shellenv)"
    fi
  fi

  if type brew > /dev/null 2>&1; then
    echo 'Homebrew is installed'
    if [ "$OS" = 'Linux' ]; then
      if [ -e /home/linuxbrew/.linuxbrew/bin/brew ]; then
        echo "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"" >> ~/.zshrc.local
      elif [ -e $HOME/.linuxbrew/bin/brew ]; then
        echo "eval \"\$($HOME/.linuxbrew/bin/brew shellenv)\"" >> ~/.zshrc.local
      fi
    fi
  else
    echo "${RED}Error:${RESET} Failed to install Homebrew." 1>&2
    exit 1
  fi
fi
echo ''

# 3. dotfiles
if ! type git ghq > /dev/null 2>&1; then
  print 'Installing packages required for dotfiles...'
  if [ "$OS" = 'Mac' ]; then
    brew install git && true
  fi
  brew install ghq && true
  echo ''
fi
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/xkumiyu/dotfiles/master/install.sh)"
echo ''

# 4. other commands
print 'Installing some packages...'
if [ "$OS" = 'Mac' ]; then
  brew bundle --global && true
elif [ "$OS" = 'Linux' ]; then
  sudo apt install -y build-essential zsh locales-all vim
  brew install httpie peco pyenv && true
fi
echo ''

# 5. python
if [ ! -e "$(pyenv root)"/plugins/xxenv-latest ]; then
  print 'Installing pyenv plugin...'
  git clone https://github.com/momo-lab/xxenv-latest.git "$(pyenv root)"/plugins/xxenv-latest
  echo ''
fi
if [ "$(pyenv latest -P)" != "$(pyenv latest -p)" ]; then
  read -r -p "Do you want to install Python $(pyenv latest -p) ? (y/N): " yn
  case "$yn" in
    [yY]*)
      print "Installing Python $(pyenv latest -p)..."
      pyenv latest install
      ;;
  esac
  echo ''
  read -r -p "Do you want to set the global Python version to $(pyenv latest -p) ? (y/N): " yn
  case "$yn" in
    [yY]*)
      pyenv latest global
      ;;
  esac
  echo ''
fi

# 6. shell and terminal
change_shell=false
if type zsh > /dev/null 2>&1 && [ "${SHELL:${#SHELL}-3}" != 'zsh' ]; then
  print "Changing login shell to $(which zsh)..."
  sudo chsh -s "$(which zsh)" "${USER:-$(whoami)}"
  change_shell=true
  echo ''
fi

install_zplug=false
if [ ! -e ~/.zplug/init.zsh ]; then
  print "Installing zplug..."
  git clone https://github.com/zplug/zplug.git ~/.zplug
  install_zplug=true
  echo ''
fi

if [ ! -e ~/.pure ]; then
  print "Downloading pure..."
  git clone https://github.com/sindresorhus/pure.git ~/.pure
  echo ''
fi

if [ ! -e ~/.vim/colors/molokai.vim ]; then
  print "Downloading molokai..."
  git clone https://github.com/tomasr/molokai ~/.vim/colors/molokai
  mv ~/.vim/colors/molokai/colors/molokai.vim ~/.vim/colors/
  echo ''
fi

# 7. docker (optional)
if [ "$OS" = 'Linux' ] && ! type docker > /dev/null 2>&1; then
  read -r -p 'Do you want to install Docker? (y/N): ' yn
  case "$yn" in
    [yY]*)
      # docker
      sudo apt install -y apt-transport-https ca-certificates software-properties-common
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
      sudo apt update
      apt-cache policy docker-ce
      sudo apt install -y docker-ce
      sudo usermod -aG docker "${USER:-$(whoami)}"

      # docker compose
      COMPOSE_VERSION="v2.2.2"
      mkdir -p $HOME/.docker/cli-plugins
      curl -fsSL -o $HOME/.docker/cli-plugins/docker-compose \
        "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)"
      chmod +x $HOME/.docker/cli-plugins/docker-compose
      ;;
    *)
      ;;
  esac
  echo ''
fi

# finish
if "$change_shell" || "$install_zplug"; then
  print 'Next steps:'
  if "$change_shell"; then
    echo -e "- Change current shell to zsh:\n    exec zsh -l"
  fi
  if "$install_zplug"; then
    echo -e "- Install zplug plugins:\n    zplug install"
  fi
else
  print 'The setup is complate!'
fi
