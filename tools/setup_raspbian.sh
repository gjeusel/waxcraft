sudo apt-get upgrade update
sudo apt-get install git python -y
sudo apt-get install transmission-gtk -y
sudo apt-get install npm -y
cd $HOME
mkdir src
cd src
git clone https://github.com/jeffjose/tget.git
cd tget && sudo npm install -g t-get

sudo apt-get install tightvncserver -y
