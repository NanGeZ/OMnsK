# [T-stability] Application-level multi-dex configuration.
#
# This file is passed to d8 as `--main-dex-list` hints (well, as
# `multiDexKeepProguard`). At `minSdk >= 21` the platform loads all
# classesN.dex files natively, so we do NOT need to keep anything
# in classes.dex for early startup. Keeping this file empty is safe
# and gives AGP maximum freedom to shard dex outputs.
#
# AGP still reads this file; leaving it comment-only is valid ProGuard
# syntax.
