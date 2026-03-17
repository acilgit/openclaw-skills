# Project Management Skill

## 概述

当用户提到项目相关内容时，必须自动同步到 SQLite 数据库。

## 数据库位置

```
/root/.openclaw/workspace/projects/projects.db
```

## 数据库表结构

### projects 表（项目）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| name | TEXT | 项目名称 |
| type | TEXT | 项目类型 |
| status | TEXT | 项目状态 |
| location | TEXT | 项目位置 |
| total_power | REAL | 总功率(kW) |
| area | REAL | 面积(平方米) |
| party_info | TEXT | 甲方/业主信息 |
| land_dept_no | TEXT | 地政署编号 |
| keywords | TEXT | 关键词 |

### contacts 表（联系人）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| project_id | INTEGER | 外键，关联项目 |
| name | TEXT | 姓名 |
| role | TEXT | 角色（业主/甲方/设计师/项目经理等） |
| company | TEXT | 公司 |
| phone | TEXT | 电话 |
| email | TEXT | 邮箱 |

### files 表（文件）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| project_id | INTEGER | 外键，关联项目 |
| file_type | TEXT | 文件类型(cad/pdf/excel/image等) |
| file_name | TEXT | 文件名 |
| file_path | TEXT | 文件路径 |
| description | TEXT | 描述 |

## 自动同步规则

### 触发条件

当用户发送以下内容时，自动同步到数据库：

1. **新建项目**
   - 用户说「创建项目 XXX」「新项目 XXX」
   - 执行：`INSERT INTO projects (name, type) VALUES ('项目名', '光伏')`

2. **项目甲方/业主**
   - 用户说「甲方是 XXX」「业主是 XXX」
   - 执行：`UPDATE projects SET party_info = 'XXX' WHERE name = '项目名'`

3. **项目位置**
   - 用户说「项目在 XXX」「位置是 XXX」
   - 执行：`UPDATE projects SET location = 'XXX' WHERE name = '项目名'`

4. **联系人信息**
   - 用户说「联系人是 XXX」「设计师是 XXX」
   - 执行：`INSERT INTO contacts (project_id, name, role) VALUES (项目ID, '姓名', '角色')`

5. **上传文件**
   - 用户发送 CAD/PDF/图片等文件
   - 保存到项目目录
   - 执行：`INSERT INTO files (project_id, file_type, file_name, file_path) VALUES (...)`

### 项目目录结构

```
/root/.openclaw/workspace/projects/
├── projects.db          # 数据库
└── {项目ID}/           # 每个项目一个目录
    ├── cad/             # CAD图纸
    ├── pdf/             # 文档
    ├── excel/           # 表格
    ├── images/          # 图片
    └── ...
```

## 动态字段扩展规则

### 核心原则

**当用户提到新的项目信息，但数据库表中没有对应字段时，必须自动创建新字段！**

### 自动建字段流程

```
用户新信息 → 检查字段是否存在 → 不存在则 ALTER TABLE 添加 → 更新数据
```

### 示例场景

| 用户输入 | 自动执行 |
|---------|---------|
| 「甲方联系人叫张三」 | 检查 contacts 表无 contact_name 字段 → 添加字段 → 插入数据 |
| 「项目投资额是500万」 | 检查 projects 表无 investment 字段 → 添加字段 → 更新数据 |
| 「并网日期是2026年6月」 | 检查 projects 表无 grid_connection_date 字段 → 添加字段 → 更新数据 |
| 「使用的是华为逆变器」 | 检查 projects 表无 inverter_brand 字段 → 添加字段 → 更新数据 |

### 字段命名规范

- 英文小写 + 下划线：如 `contact_name`, `investment`, `grid_connection_date`
- 语义清晰：望文知意
- 类型统一：TEXT 类型（最通用）

### 自动建字段命令模板

```bash
# 1. 检查字段是否存在
sqlite3 /root/.openclaw/workspace/projects/projects.db "PRAGMA table_info(projects);" | grep "字段名"

# 2. 如果不存在，添加字段
sqlite3 /root/.openclaw/workspace/projects/projects.db "ALTER TABLE projects ADD COLUMN 字段名 TEXT;"

# 3. 更新数据
sqlite3 /root/.openclaw/workspace/projects/projects.db "UPDATE projects SET 字段名 = '值' WHERE name = '项目名';"
```

## 使用方法

1. 检测用户消息是否包含项目关键词
2. 如果需要创建/更新项目，优先查询现有项目ID
3. 检查目标字段是否存在：
   - 存在 → 直接更新
   - 不存在 → 自动用 ALTER TABLE 添加新字段
4. 使用 sqlite3 命令执行数据库操作
5. 操作完成后告知用户已同步（包括新建的字段名）

## 示例查询命令

```bash
# 查询所有项目
sqlite3 /root/.openclaw/workspace/projects/projects.db "SELECT id, name, party_info, location FROM projects;"

# 查询项目联系人
sqlite3 /root/.openclaw/workspace/projects/projects.db "SELECT * FROM contacts WHERE project_id = 1;"

# 查询项目文件
sqlite3 /root/.openclaw/workspace/projects/projects.db "SELECT * FROM files WHERE project_id = 1;"
```
