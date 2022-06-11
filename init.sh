#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

cat << EOF > ./update.sh
#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

function failMsg ()
{
    echo -e "|\n'- \${1}\\n"
    exit 1
}

if [[ -d onboarding/.git/ ]]; then
    git -C onboarding/ pull --rebase || \
        failMsg 'onboarding/ repo not clean. Cannot update it. Aborting.'
else
    git clone https://gitlab.com/serpent-os/core/onboarding
fi

exec onboarding/update-all.sh
EOF

chmod a+x ./update.sh
exec ./update.sh
