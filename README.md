# DSG_2018_Round1
Codes and files for Data Science Game 2018 (online round)

Fast start to run the codes on LEQR server:
1. If you do not have Google Chrome, download the installation file into your shared folder. 
You will not be able to download them through IE on server's GUI, since it's prohibited by admin.
2. If you do not have Anaconda, please download installation file into your shared folder. I recommend Miniconda.
https://conda.io/miniconda.html
3. On the server, run installation managers for Chrome and Conda.
4. Open terminal type `conda create -n dsg python=3.6 git scikit-learn pandas numpy seaborn matplotlib jupyterlab`
If terminal cannot find `conda`command, please type the same in the anaconda prompt (terminal with all the environmental variables set up for you - you can find it in the start menu).
5. Activate conda environment by `activate dsg`. Now in your terminal you should see `(dsg)` before the path. 
6. Install lightgbm, since it is not available through conda manager, we will install it through pip manager `pip install lightgbm`
7. Navigate to the shared folder, we will clone the git hub repo there, you won't have to to do it many times if you are using more then one LEQR server. In windows terminal `cd`won't work to change disks, so type just the disk with colon. My shared folder is on *H* disk, so I type `H:`. 
8. Now you can clone the repo by using `git clone https://github.com/kozodoi/DSG_2018_Round1.git`
9. After cloning is completed, navigate into *DSG_2018_Round1*, type `jupyter lab`. And you are good to go.
