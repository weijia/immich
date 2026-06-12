#!/bin/bash
# 版本号生成脚本
# 规则：
#   - 正好在 tag 上：x.y.z
#   - tag 后有新提交：x.y.z-YYYYMMDD.HHMMSSCST
#   - 无 tag：0.0.0-YYYYMMDD.HHMMSSCST
# 版本号中不含 + 号（Android 不允许）
set -e

# 获取最近的 tag（排除 build 日期类型的 tag）
TAG=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)

# 东八区构建时间
BUILD_DATETIME=$(TZ='Asia/Shanghai' date '+%Y%m%d.%H%M%S')

if [ -n "$TAG" ]; then
    # 有 tag，使用 tag + 构建时间戳
    BASE_VERSION="${TAG#v}"

    # 判断是否正好在 tag 上
    COMMIT_COUNT=$(git rev-list "${TAG}..HEAD" --count 2>/dev/null || echo "0")

    if [ "$COMMIT_COUNT" -gt 0 ]; then
        # tag 之后有新提交：1.1.0-20260609.143000CST
        VERSION_NAME="${BASE_VERSION}-${BUILD_DATETIME}CST"
    else
        # 正好在 tag 上：1.1.0
        VERSION_NAME="${BASE_VERSION}"
    fi

    VERSION_CODE="1"
    BUILD_TYPE="tag"
    BUILD_TAG="$TAG"
else
    # 无 tag：0.0.0-20260609.143000CST
    VERSION_NAME="0.0.0-${BUILD_DATETIME}CST"

    # 用时间戳作为 versionCode（取后 9 位，确保不超过 Android 限制 2100000000）
    TIMESTAMP=$(TZ='Asia/Shanghai' date '+%Y%m%d%H%M%S')
    VERSION_CODE=$(echo "$TIMESTAMP" | sed 's/^.*\(.\{9\}\)$/\1/')
    if [ "$VERSION_CODE" -gt 2100000000 ]; then
        VERSION_CODE=$((VERSION_CODE % 2100000000))
    fi

    BUILD_TYPE="datetime"
fi

# 输出到 GitHub Actions（使用小写变量名）
echo "version_name=${VERSION_NAME}"
echo "version_code=${VERSION_CODE}"
echo "build_type=${BUILD_TYPE}"
echo "build_tag=${BUILD_TAG}"
echo "build_datetime=${BUILD_DATETIME}"
echo "build_timezone=CST"