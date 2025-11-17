# ChatCommunity iOS App

ChatCommunity 是一个使用 SwiftUI 实现的示例聊天客户端应用，展示了如何通过服务器收发消息。应用包含基本的消息列表、发送输入框以及一个可配置的服务端网络层，便于对接你现有的聊天后端。

## 功能概览
- SwiftUI 构建的响应式聊天界面。
- 可配置的服务器地址与 API 路径（参见 `ServerConfiguration.swift`）。
- `URLSession` 实现的发送与轮询获取消息的网络层。
- `ObservableObject` 驱动的 `ChatViewModel`，自动轮询服务器并更新 UI。

## 目录结构
```
ChatCommunity/
├── ChatCommunity.xcodeproj        # Xcode 项目文件
├── ChatCommunity                  # App 源码
│   ├── App                        # App 入口
│   ├── Models                     # 数据模型
│   ├── Networking                 # 网络层
│   ├── ViewModels                 # 视图模型
│   ├── Views                      # SwiftUI 视图
│   └── Resources                  # 资源（Info.plist / Assets 等）
├── README.md                      # 本说明文档
```

## 服务器约定
`ChatService` 默认假设服务器提供如下 REST 接口（可以根据需要修改）：
- `GET /messages?since=<ISO8601>`：返回按时间倒序排列的新消息数组。
- `POST /messages`：Body 为 `{ "author": "名字", "content": "内容" }`，返回已写入的消息 JSON。

服务器返回的消息 JSON 形如：
```json
{
  "id": "uuid",
  "author": "Codex",
  "content": "Hello",
  "timestamp": "2024-06-26T07:00:00Z"
}
```

## 本地运行
1. 打开 `ChatCommunity.xcodeproj`，选择你的开发团队并确认 Bundle Identifier。
2. 根据自己的服务器修改 `ServerConfiguration.swift` 中的 `baseURL` 和 `messagePath`。
3. 在模拟器或真机上运行，输入昵称（第一次发送时会提示），即可开始聊天。

## 后端（FastAPI + Docker）
仓库附带了一个简单的 FastAPI 服务端，提供与前端约定一致的 REST 接口，默认监听 `:8080`。

### 直接使用 Docker（含 Ollama）
```bash
# 确保本地已安装并运行 ollama，且已拉取所需模型（默认 deepseek-r1:8b）
ollama pull deepseek-r1:8b
docker compose up --build
```
默认 `docker-compose.yml` 会将 `OLLAMA_BASE_URL` 指向 `http://host.docker.internal:11434`，方便容器内访问宿主机上的 Ollama 服务。若在 Linux 上运行，可改用 `http://172.17.0.1:11434` 或通过 `extra_hosts` 显式配置。

### 本地运行（无 Docker）
```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
# 单机运行时确保 Ollama 在默认端口监听，或通过环境变量覆盖
export OLLAMA_BASE_URL=http://localhost:11434
uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload
```

### API 说明
- `GET /messages?since=<ISO8601>`：返回自 `since` 之后的新消息（若缺省则为全部，按时间升序）。
- `POST /messages`：Body `{ "author": "名字", "content": "内容" }`，服务端会将消息写入并调用 Ollama 模型生成 AI 回复，随后由客户端轮询获取。

### 关键环境变量
- `OLLAMA_BASE_URL`：Ollama 服务地址，默认 `http://localhost:11434`。
- `OLLAMA_MODEL`：使用的模型名（默认 `deepseek-r1:8b`）。
- `OLLAMA_SYSTEM_PROMPT`：可选系统提示词，用于定制 AI 行为。
- `OLLAMA_HISTORY_LIMIT`：发送给模型的历史消息条数（默认 20）。

## 环境变量/配置
若希望在 CI 或不同环境中切换服务器，可在 `Info.plist` 中添加自定义字段（例如 `ChatServerURL`），在 `ServerConfiguration` 中通过 `Bundle` 读取。文档中给出示例实现。

## 未来扩展建议
- 使用 WebSocket 代替轮询以降低延迟与网络压力。
- 增加用户登录/鉴权以及消息持久化。
- 使用 Combine 或 SwiftData/CoreData 缓存历史记录。
- 对接推送通知，实现实时提醒。
