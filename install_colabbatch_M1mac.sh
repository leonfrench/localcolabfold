#!/bin/bash

# check commands
type wget || { echo "wget command is not installed. Please install it at first using Homebrew." ; exit 1 ; }
type gsed || { echo "gnu-sed command is not installed. Please install it at first using Homebrew." ; exit 1 ; }
type hhsearch || { echo "hhsearch command is not installed. Please install it at first using Homebrew." ; exit 1 ; }
type kalign || { echo "kalign command is not installed. Please install it at first using Homebrew." ; exit 1 ; }

# check whether miniforge is present
test -f "/opt/homebrew/Caskroom/miniforge/base/etc/profile.d/conda.sh" || { echo "Install miniforge by using Homebrew before installation. \n 'brew install --cask miniforge'" ; exit 1 ; }

# check whether Apple Silicon (M1 mac) or Intel Mac
arch_name="$(uname -m)"

if [ "${arch_name}" = "x86_64" ]; then
    if [ "$(sysctl -in sysctl.proc_translated)" = "1" ]; then
        echo "Running on Rosetta 2"
    else
        echo "Running on native Intel"
    fi
    echo "This installer is only for Apple Silicon. Use install_colabfold_intelmac.sh to install on this Mac."
    exit 1
elif [ "${arch_name}" = "arm64" ]; then
    echo "Running on Apple Silicon (M1 mac)"
else
    echo "Unknown architecture: ${arch_name}"
    exit 1
fi

CURRENTPATH=`pwd`
COLABFOLDDIR="${CURRENTPATH}/colabfold_batch"

mkdir -p ${COLABFOLDDIR}
cd ${COLABFOLDDIR}
wget https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt --no-check-certificate
. "/opt/homebrew/Caskroom/miniforge/base/etc/profile.d/conda.sh"
conda create -p $COLABFOLDDIR/colabfold-conda python=3.8 -y
conda activate $COLABFOLDDIR/colabfold-conda
conda update -n base conda -y

conda install -y -c conda-forge python=3.8 openmm==7.5.1 pdbfixer jupyter matplotlib py3Dmol tqdm biopython==1.79 immutabledict==2.0.0
conda install -y -c apple tensorflow-deps
# patch to openmm
wget -qnc https://raw.githubusercontent.com/deepmind/alphafold/main/docker/openmm.patch --no-check-certificate
(cd ${COLABFOLDDIR}/colabfold-conda/lib/python3.8/site-packages; patch -s -p0 < ${COLABFOLDDIR}/openmm.patch)
rm openmm.patch
# Download the updater
wget -qnc https://raw.githubusercontent.com/YoshitakaMo/localcolabfold/main/update_M1mac.sh --no-check-certificate
chmod +x update_M1mac.sh
# install ColabFold and Jaxlib
colabfold-conda/bin/python3.8 -m pip install https://files.pythonhosted.org/packages/bd/57/88cea9e14dacaea82ca86fac2bf6ecb8b7fd99622d776e4131786ce5b65e/tensorflow_macos-2.7.0-cp38-cp38-macosx_11_0_arm64.whl
colabfold-conda/bin/python3.8 -m pip install git+https://github.com/deepmind/tree.git
colabfold-conda/bin/python3.8 -m pip install git+https://github.com/google/ml_collections.git
colabfold-conda/bin/python3.8 -m pip install dm-haiku appdirs pandas absl-py docker
colabfold-conda/bin/python3.8 -m pip install alphafold-colabfold --no-deps --no-color
colabfold-conda/bin/python3.8 -m pip install "colabfold[alphafold] @ git+https://github.com/sokrypton/ColabFold" --no-deps --no-color
colabfold-conda/bin/python3.8 -m pip install jaxlib==0.3.10 --no-deps --no-color
colabfold-conda/bin/python3.8 -m pip install jax==0.3.13 chex scipy toolz --no-deps --no-color

# bin directory to run
mkdir -p $COLABFOLDDIR/bin
cd $COLABFOLDDIR/bin
cat << EOF > colabfold_batch
#!/bin/sh
export COLABFOLDDIR=$COLABFOLDDIR
export PATH="\${COLABFOLDDIR}/colabfold-conda/bin:\$PATH"
\$COLABFOLDDIR/colabfold-conda/bin/colabfold_batch --cpu \$@
EOF
chmod +x colabfold_batch

# hack to share the parameter files in a workstation.
gsed -i -e "s#props_path = \"stereo_chemical_props.txt\"#props_path = \"${COLABFOLDDIR}/stereo_chemical_props.txt\"#" ${COLABFOLDDIR}/colabfold-conda/lib/python3.8/site-packages/colabfold/batch.py

echo "-----------------------------------------"
echo "Installation of colabfold_batch finished."
echo "Note: AlphaFold2 weight parameters will be downloaded at ~/Library/Caches/colabfold/params directory at your first run."
echo "Add ${COLABFOLDDIR}/bin to your environment variable PATH to run 'colabfold_batch'."
echo "i.e. For Bash, export PATH=\"${COLABFOLDDIR}/bin:\$PATH\""
echo "For more details, please type 'colabfold_batch --help'."
