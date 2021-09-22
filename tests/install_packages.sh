apt-get update
apt-get install -y python3-pip
pip3 install numpy
pip3 install matplotlib
pip3 install pandas

echo "backend: Agg" > ~/.config/matplotlib/matplotlibrc
