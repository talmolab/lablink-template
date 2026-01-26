#!/bin/bash                                                                                                                                                    
set -e

echo "Installing Foldseek..."

# Create installation directory                                                                                                                                
FOLDSEEK_DIR="/home/client/foldseek"
mkdir -p "$FOLDSEEK_DIR"
cd "$FOLDSEEK_DIR"                                                                                                                                         

# Download and extract Foldseek GPU build                                                                                                                      
# Requires: glibc >= 2.17 and NVIDIA driver >= 525.60.13                                                                                                       
wget -q https://mmseqs.com/foldseek/foldseek-linux-gpu.tar.gz                                                                                                  
tar xzf foldseek-linux-gpu.tar.gz                                                                                                                              
rm foldseek-linux-gpu.tar.gz                                                                                                                                   

# Add to PATH for current session                                                                                                                              
export PATH="$FOLDSEEK_DIR/foldseek/bin:$PATH"                                                                                                                 

# Add to PATH permanently for future sessions                                                                                                                  
echo "export PATH=\"$FOLDSEEK_DIR/foldseek/bin:\$PATH\"" >> /home/client/.bashrc
echo "export PATH=\"$FOLDSEEK_DIR/foldseek/bin:\$PATH\"" >> /home/client/.profile

echo "Foldseek installed successfully. Version: $(foldseek version 2>/dev/null || echo 'check with foldseek -h')"                                              
