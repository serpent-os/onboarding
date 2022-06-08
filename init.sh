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

if [[ -d onboarding/.git/ ]]; then
    pushd onboarding
    git pull --rebase
    popd
else
    git clone https://gitlab.com/serpent-os/core/onboarding
fi

exec onboarding/update-all.sh
EOF

chmod a+x ./update.sh
exec ./update.sh
