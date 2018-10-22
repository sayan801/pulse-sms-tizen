# 1. Delete the previous build
rm -rf tizen/static
rm tizen/index.html

# 2. Copy files from /web/dist to /tizen
cp -R web/dist/* tizen

# 3. Vue.js specific build replacements
cd tizen
sed -i'.original' 's_/static_static_g' index.html

# 4. Cleanup unnecessary files
rm index.html.original
rm static/js/*.map
rm static/css/*.map
