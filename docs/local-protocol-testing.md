# 本地协议验收

sendreq 的内置 **Sendreq Demo Example** 通过三个本地服务验收。它们只监听回环地址：

```bash
cd ../go-rest && go run .
cd ../go-ws && go run .
cd ../go-grpc && go run .
```

服务地址分别为 REST `http://127.0.0.1:8081`、WebSocket `ws://127.0.0.1:8080/ws` 和 gRPC `http://127.0.0.1:50051`。

## 示例请求

REST 文件夹包含 List users、Create user、Replace user 1、Patch user 1 和 Delete user 1。按顺序执行后再次发送 List users，应确认用户已经删除；重启 `go-rest` 可恢复初始数据。

对于 **Local echo**，连接 `ws://127.0.0.1:8080/ws` 并发送 Text、JSON、XML 和 MessagePack 帧。每条出站帧都必须有对应的入站记录。

对于 **Create order**，安装包中的 `assets/demo/order.proto` 会恢复 `.order.v1.OrderService/CreateOrder`。向 `http://127.0.0.1:50051` 发送默认请求并保持 TLS 关闭；成功响应的状态为 `0`，订单 id 以 `ORD-` 开头。

REST Create user 成功返回后，创建并导出 Markdown 文档。确认文件包含请求方法、URL、状态 `201`、响应头和格式化 JSON 响应示例；Secret 请求头值必须保持脱敏。
