export ACME=/c/Users/Dave/Downloads/acme0.96.4win/acme 
export VICE=/c/Users/Dave/Downloads/GTK3VICE-3.6.1-win64/bin
${ACME}/acme -f cbm -l build/labels -o build/bounce.prg bounce.asm
[ $? -eq 0 ] || exit 1
[ $? -eq 0 ] && ${VICE}/c1541 << EOF
attach angular20.d64
delete bounce.ml
write build/bounce.prg bounce.ml
EOF
[ $? -eq 0 ] && ${VICE}/xvic.exe -moncommands build/labels angular20.d64
rm vic20_files/*
cd vic20_files
[ $? -eq 0 ] && ${VICE}/c1541 << EOF
attach ../angular20.d64
extract
EOF
cd ..
pwd