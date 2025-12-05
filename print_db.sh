#!/bin/bash

# 书签数据库内容查看工具
# 使用方法: ./debug_bookmarks_db.sh [数据库文件路径]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_separator() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}"
}

function print_usage() {
    echo "用法:"
    echo "  ./debug_bookmarks_db.sh [数据库文件路径]"
    echo ""
    echo "示例:"
    echo "  ./debug_bookmarks_db.sh .nvim/bookmarks.sqlite.db"
    echo "  ./debug_bookmarks_db.sh /path/to/project/.nvim/bookmarks.sqlite.db"
    echo ""
}

# 检查参数
if [ $# -eq 0 ]; then
    echo -e "${RED}错误: 请提供数据库文件路径${NC}"
    print_usage
    exit 1
fi

DB_PATH="$1"

# 检查文件是否存在
if [ ! -f "$DB_PATH" ]; then
    echo -e "${RED}错误: 数据库文件不存在: '$DB_PATH'${NC}"
    echo -e "${YELLOW}请确保:${NC}"
    echo "1. 文件路径正确"
    echo "2. 文件存在"
    echo "3. 你有读取权限"
    exit 1
fi

# 检查 sqlite3 是否可用
if ! command -v sqlite3 &>/dev/null; then
    echo -e "${RED}错误: sqlite3 命令未找到${NC}"
    echo -e "${YELLOW}请安装 sqlite3:${NC}"
    echo "  Ubuntu/Debian: sudo apt-get install sqlite3"
    echo "  macOS: brew install sqlite3"
    echo "  CentOS/RHEL: sudo yum install sqlite3"
    exit 1
fi

echo -e "${GREEN}读取书签数据库: $DB_PATH${NC}"

print_separator "数据库基本信息"

# 获取文件大小
FILE_SIZE=$(ls -lh "$DB_PATH" | awk '{print $5}')
echo "文件路径: $DB_PATH"
echo "文件大小: $FILE_SIZE"

print_separator "数据库表结构"

echo "数据库中的所有表:"
sqlite3 "$DB_PATH" ".tables"

print_separator "表结构详情"

# 获取所有表名
TABLES=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table';")

for table in $TABLES; do
    echo -e "\n${YELLOW}表: $table${NC}"
    echo "表结构:"
    sqlite3 "$DB_PATH" ".schema $table"

    # 获取记录数
    COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM $table;")
    echo "记录数: $COUNT"

    if [ "$COUNT" -gt 0 ]; then
        echo "表内容:"
        sqlite3 "$DB_PATH" "SELECT * FROM $table;" | while IFS='|' read -r line; do
            if [ -n "$line" ]; then
                echo "  $line"
            fi
        done
    else
        echo "  (此表为空)"
    fi
    echo "----------------------------------------"
done

print_separator "有用的查询"

echo -e "\n${YELLOW}1. 所有书签节点:${NC}"
sqlite3 "$DB_PATH" "SELECT id, name, type, location_path, location_line, created_at FROM nodes WHERE type='bookmark' ORDER BY created_at DESC;" 2>/dev/null || echo "  无书签数据"

echo -e "\n${YELLOW}2. 所有列表节点:${NC}"
sqlite3 "$DB_PATH" "SELECT id, name, type, created_at FROM nodes WHERE type='list' ORDER BY created_at DESC;" 2>/dev/null || echo "  无列表数据"

echo -e "\n${YELLOW}3. 活动列表:${NC}"
sqlite3 "$DB_PATH" "SELECT al.list_id, n.name as list_name, al.updated_at FROM active_list al LEFT JOIN nodes n ON al.list_id = n.id;" 2>/dev/null || echo "  无活动列表"

echo -e "\n${YELLOW}4. 节点关系:${NC}"
sqlite3 "$DB_PATH" "SELECT nr.parent_id, nr.child_id, p.name as parent_name, c.name as child_name FROM node_relationships nr LEFT JOIN nodes p ON nr.parent_id = p.id LEFT JOIN nodes c ON nr.child_id = c.id;" 2>/dev/null || echo "  无关系数据"

print_separator "可执行的 sqlite3 命令"

echo "如果你想手动查看数据库，可以使用以下命令:"
echo "  sqlite3 '$DB_PATH'"
echo ""
echo "常用 sqlite3 命令:"
echo "  .tables                    - 显示所有表"
echo "  .schema [表名]             - 显示表结构"
echo "  .headers on                - 显示列名"
echo "  .mode column              - 列对齐模式"
echo "  SELECT * FROM nodes;       - 查看 nodes 表"
echo "  SELECT * FROM node_relationships; - 查看关系表"
echo "  .quit                      - 退出"

print_separator "读取完成"

echo -e "${GREEN}数据库信息读取完成!${NC}"
