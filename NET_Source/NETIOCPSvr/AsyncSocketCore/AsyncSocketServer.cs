using System;
using System.Text;
using System.Net;
using System.Net.Sockets;
using System.Threading;

namespace NETIOCPSvr
{
    /// <summary>
    /// 服务入口，建立Socket监听，负责接收连接，
    /// 绑定连接对象，处理异步事件返回的接收和发送事件
    /// </summary>
    public class AsyncSocketServer
    {        
        private Socket listenSocket;
        /// <summary>
        /// 最大支持连接个数
        /// </summary>
        private int m_numConnections;
        /// <summary>
        /// 每个连接接收缓存大小
        /// </summary>
        private int m_receiveBufferSize;
        /// <summary>
        /// 限制访问接收连接的线程数，用来控制最大并发数
        /// </summary>
        private Semaphore m_maxNumberAcceptedClients;
        /// <summary>
        /// Socket最大超时时间，单位为MS
        /// </summary>
        private int m_socketTimeOutMS;
        public int SocketTimeOutMS { get { return m_socketTimeOutMS; } set { m_socketTimeOutMS = value; } }
        /// <summary>
        /// 管理所有空闲的AsyncSocketUserToken，采用栈的管理方式，后进先出
        /// </summary>
        private AsyncSocketUserTokenPool m_asyncSocketUserTokenPool;
        /// <summary>
        /// 管理所有正在执行的AsyncSocketUserToken，是一个列表
        /// </summary>
        private AsyncSocketUserTokenList m_asyncSocketUserTokenList;
        /// <summary>
        /// 管理所有正在执行的AsyncSocketUserToken，是一个列表
        /// </summary>
        public AsyncSocketUserTokenList AsyncSocketUserTokenList { get { return m_asyncSocketUserTokenList; } }

        private LogOutputSocketProtocolMgr m_logOutputSocketProtocolMgr;
        /// <summary>
        /// LogOutputSocketProtocol的管理对象
        /// </summary>
        public LogOutputSocketProtocolMgr LogOutputSocketProtocolMgr { get { return m_logOutputSocketProtocolMgr; } }
        /// <summary>
        /// UploadSocketProtocol的管理对象，用于检测是否同时上传同一个文件
        /// </summary>
        private UploadSocketProtocolMgr m_uploadSocketProtocolMgr;
        /// <summary>
        /// UploadSocketProtocol的管理对象，用于检测是否同时上传同一个文件
        /// </summary>
        public UploadSocketProtocolMgr UploadSocketProtocolMgr { get { return m_uploadSocketProtocolMgr; } }
        /// <summary>
        /// DownloadSocketProtocol的管理对象
        /// </summary>
        private DownloadSocketProtocolMgr m_downloadSocketProtocolMgr;
        /// <summary>
        /// DownloadSocketProtocol的管理对象
        /// </summary>
        public DownloadSocketProtocolMgr DownloadSocketProtocolMgr { get { return m_downloadSocketProtocolMgr; } }
        /// <summary>
        /// 守护进程，用于关闭超时连接
        /// </summary>
        private DaemonThread m_daemonThread;
        /// <summary>
        /// SocketAsyncEventArgs封装和MSDN的不同点
        /// MSDN在http://msdn.microsoft.com/zh-cn/library/system.net.sockets.socketasynceventargs(v=vs.110).aspx
        /// 实现了示例代码，并实现了初步的池化处理，我们是在它的基础上扩展实现了接收数据缓冲，发送数据队列
        /// ，并把发送SocketAsyncEventArgs和接收SocketAsyncEventArgs分开，
        /// 并实现了协议解析单元，这样做的好处是方便后续逻辑实现文件的上传，下载和日志输出。
        /// </summary>
        /// <param name="numConnections"></param>
        public AsyncSocketServer(int numConnections)
        {
            m_numConnections = numConnections;
            m_receiveBufferSize = ProtocolConst.ReceiveBufferSize;

            m_asyncSocketUserTokenPool = new AsyncSocketUserTokenPool(numConnections);
            m_asyncSocketUserTokenList = new AsyncSocketUserTokenList();
            m_maxNumberAcceptedClients = new Semaphore(numConnections, numConnections);

            m_logOutputSocketProtocolMgr = new LogOutputSocketProtocolMgr();
            m_uploadSocketProtocolMgr = new UploadSocketProtocolMgr();
            m_downloadSocketProtocolMgr = new DownloadSocketProtocolMgr();
        }
        /// <summary>
        /// 按照连接数建立读写对象
        /// </summary>
        public void Init()
        {
            AsyncSocketUserToken userToken;
            for (int i = 0; i < m_numConnections; i++)
            {
                userToken = new AsyncSocketUserToken(m_receiveBufferSize);
                userToken.ReceiveEventArgs.Completed += new EventHandler<SocketAsyncEventArgs>(IO_Completed);
                userToken.SendEventArgs.Completed += new EventHandler<SocketAsyncEventArgs>(IO_Completed);
                m_asyncSocketUserTokenPool.Push(userToken);
            }
        }
        /// <summary>
        /// 建立一个Socket监听对象
        /// </summary>
        /// <param name="localEndPoint"></param>
        public void Start(IPEndPoint localEndPoint)
        {
            listenSocket = new Socket(localEndPoint.AddressFamily, SocketType.Stream, ProtocolType.Tcp);
            listenSocket.Bind(localEndPoint);
            listenSocket.Listen(m_numConnections);
            Program.Logger.InfoFormat("Start listen socket {0} success", localEndPoint.ToString());
            //for (int i = 0; i < 64; i++) //不能循环投递多次AcceptAsync，会造成只接收8000连接后不接收连接了
            StartAccept(null);
            m_daemonThread = new DaemonThread(this);
        }
        /// <summary>
        /// 开始接受连接，SocketAsyncEventArgs有连接时会通过Completed事件通知外面
        /// </summary>
        /// <param name="acceptEventArgs"></param>
        public void StartAccept(SocketAsyncEventArgs acceptEventArgs)
        {
            if (acceptEventArgs == null)
            {
                acceptEventArgs = new SocketAsyncEventArgs();
                acceptEventArgs.Completed += new EventHandler<SocketAsyncEventArgs>(AcceptEventArg_Completed);
            }
            else
            {
                acceptEventArgs.AcceptSocket = null; //释放上次绑定的Socket，等待下一个Socket连接
            }

            m_maxNumberAcceptedClients.WaitOne(); //获取信号量
            bool willRaiseEvent = listenSocket.AcceptAsync(acceptEventArgs);
            if (!willRaiseEvent)
            {
                ProcessAccept(acceptEventArgs);
            }
        }
        /// <summary>
        /// 接受连接响应
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="acceptEventArgs"></param>
        void AcceptEventArg_Completed(object sender, SocketAsyncEventArgs acceptEventArgs)
        {
            try
            {
                ProcessAccept(acceptEventArgs);
            }
            catch (Exception E)
            {
                Program.Logger.ErrorFormat("Accept client {0} error, message: {1}", acceptEventArgs.AcceptSocket, E.Message);
                Program.Logger.Error(E.StackTrace);  
            }            
        }

        private void ProcessAccept(SocketAsyncEventArgs acceptEventArgs)
        {
            Program.Logger.InfoFormat("Client connection accepted. Local Address: {0}, Remote Address: {1}",
                acceptEventArgs.AcceptSocket.LocalEndPoint, acceptEventArgs.AcceptSocket.RemoteEndPoint);

            AsyncSocketUserToken userToken = m_asyncSocketUserTokenPool.Pop();
            m_asyncSocketUserTokenList.Add(userToken); //添加到正在连接列表
            userToken.ConnectSocket = acceptEventArgs.AcceptSocket;
            userToken.ConnectDateTime = DateTime.Now;

            try
            {
                bool willRaiseEvent = userToken.ConnectSocket.ReceiveAsync(userToken.ReceiveEventArgs); //投递接收请求
                if (!willRaiseEvent)
                {
                    lock (userToken)
                    {
                        ProcessReceive(userToken.ReceiveEventArgs);
                    }
                }                    
            }
            catch (Exception E)
            {
                Program.Logger.ErrorFormat("Accept client {0} error, message: {1}", userToken.ConnectSocket, E.Message);
                Program.Logger.Error(E.StackTrace);                
            }            

            StartAccept(acceptEventArgs); //把当前异步事件释放，等待下次连接
        }
        /// <summary>
        /// NET底层IO线程也是每个异步事件都是由不同的线程返回到Completed事件，
        /// 因此在Completed事件需要对用户对象进行加锁，
        /// 避免同一个用户对象同时触发两个Completed事件。
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="asyncEventArgs"></param>
        void IO_Completed(object sender, SocketAsyncEventArgs asyncEventArgs)
        {
            AsyncSocketUserToken userToken = asyncEventArgs.UserToken as AsyncSocketUserToken;
            userToken.ActiveDateTime = DateTime.Now;
            try
            {                
                lock (userToken)
                {//避免同一个userToken同时有多个线程操作
                    if (asyncEventArgs.LastOperation == SocketAsyncOperation.Receive)
                        ProcessReceive(asyncEventArgs);
                    else if (asyncEventArgs.LastOperation == SocketAsyncOperation.Send)
                        ProcessSend(asyncEventArgs);
                    else
                        throw new ArgumentException("The last operation completed on the socket was not a receive or send");
                }   
            }
            catch (Exception E)
            {
                Program.Logger.ErrorFormat("IO_Completed {0} error, message: {1}", userToken.ConnectSocket, E.Message);
                Program.Logger.Error(E.StackTrace);
            }                     
        }
        /// <summary>
        /// 接收事件响应函数,接收的逻辑
        /// </summary>
        /// <param name="receiveEventArgs"></param>
        private void ProcessReceive(SocketAsyncEventArgs receiveEventArgs)
        {
            AsyncSocketUserToken userToken = receiveEventArgs.UserToken as AsyncSocketUserToken;
            if (userToken.ConnectSocket == null)
                return;
            userToken.ActiveDateTime = DateTime.Now;
            if (userToken.ReceiveEventArgs.BytesTransferred > 0 && userToken.ReceiveEventArgs.SocketError == SocketError.Success)
            {
                int offset = userToken.ReceiveEventArgs.Offset;
                int count = userToken.ReceiveEventArgs.BytesTransferred;
                if ((userToken.AsyncSocketInvokeElement == null) & (userToken.ConnectSocket != null)) //存在Socket对象，并且没有绑定协议对象，则进行协议对象绑定
                {
                    BuildingSocketInvokeElement(userToken);
                    offset = offset + 1;
                    count = count - 1;
                }
                if (userToken.AsyncSocketInvokeElement == null) //如果没有解析对象，提示非法连接并关闭连接
                {
                    Program.Logger.WarnFormat("Illegal client connection. Local Address: {0}, Remote Address: {1}", userToken.ConnectSocket.LocalEndPoint, 
                        userToken.ConnectSocket.RemoteEndPoint);
                    CloseClientSocket(userToken);
                }
                else
                {
                    if (count > 0) //处理接收数据
                    {
                        if (!userToken.AsyncSocketInvokeElement.ProcessReceive(userToken.ReceiveEventArgs.Buffer, offset, count))
                        { //如果处理数据返回失败，则断开连接
                            CloseClientSocket(userToken);
                        }
                        else //否则投递下次介绍数据请求
                        {
                            bool willRaiseEvent = userToken.ConnectSocket.ReceiveAsync(userToken.ReceiveEventArgs); //投递接收请求
                            if (!willRaiseEvent)
                                ProcessReceive(userToken.ReceiveEventArgs);
                        }
                    }
                    else
                    {
                        bool willRaiseEvent = userToken.ConnectSocket.ReceiveAsync(userToken.ReceiveEventArgs); //投递接收请求
                        if (!willRaiseEvent)
                            ProcessReceive(userToken.ReceiveEventArgs);
                    }
                }
            }
            else
            {
                CloseClientSocket(userToken);
            }
        }
        /// <summary>
        /// 协议第一个字节是协议标识，因此在接收到第一个字节的时候需要绑定协议解析对象
        /// </summary>
        /// <param name="userToken"></param>
        private void BuildingSocketInvokeElement(AsyncSocketUserToken userToken)
        {
            byte flag = userToken.ReceiveEventArgs.Buffer[userToken.ReceiveEventArgs.Offset];
            if (flag == (byte)ProtocolFlag.Upload)
                userToken.AsyncSocketInvokeElement = new UploadSocketProtocol(this, userToken);
            else if (flag == (byte)ProtocolFlag.Download)
                userToken.AsyncSocketInvokeElement = new DownloadSocketProtocol(this, userToken);
            else if (flag == (byte)ProtocolFlag.RemoteStream)
                userToken.AsyncSocketInvokeElement = new RemoteStreamSocketProtocol(this, userToken);
            else if (flag == (byte)ProtocolFlag.Throughput)
                userToken.AsyncSocketInvokeElement = new ThroughputSocketProtocol(this, userToken);
            else if (flag == (byte)ProtocolFlag.Control)
                userToken.AsyncSocketInvokeElement = new ControlSocketProtocol(this, userToken);
            else if (flag == (byte)ProtocolFlag.LogOutput)
                userToken.AsyncSocketInvokeElement = new LogOutputSocketProtocol(this, userToken);
            if (userToken.AsyncSocketInvokeElement != null)
            {
                Program.Logger.InfoFormat("Building socket invoke element {0}.Local Address: {1}, Remote Address: {2}",
                    userToken.AsyncSocketInvokeElement, userToken.ConnectSocket.LocalEndPoint, userToken.ConnectSocket.RemoteEndPoint);
            } 
        }
        /// <summary>
        /// 发送事件响应函数,发送的逻辑,把发送数据放到一个列表中，当上一个发送事件完成响应Completed事件，
        /// 这时我们需要检测发送队列中是否存在未发送的数据，如果存在则继续发送
        /// </summary>
        /// <param name="sendEventArgs"></param>
        /// <returns></returns>
        private bool ProcessSend(SocketAsyncEventArgs sendEventArgs)
        {
            AsyncSocketUserToken userToken = sendEventArgs.UserToken as AsyncSocketUserToken;
            if (userToken.AsyncSocketInvokeElement == null)
                return false;
            userToken.ActiveDateTime = DateTime.Now;
            if (sendEventArgs.SocketError == SocketError.Success)
                return userToken.AsyncSocketInvokeElement.SendCompleted(); //调用子类回调函数
            else
            {
                CloseClientSocket(userToken);
                return false;
            }
        }

        public bool SendAsyncEvent(Socket connectSocket, SocketAsyncEventArgs sendEventArgs, byte[] buffer, int offset, int count)
        {
            if (connectSocket == null)
                return false;
            sendEventArgs.SetBuffer(buffer, offset, count);
            bool willRaiseEvent = connectSocket.SendAsync(sendEventArgs);
            if (!willRaiseEvent)
            {
                return ProcessSend(sendEventArgs);
            }
            else
                return true;
        }
        /// <summary>
        /// 当一个SocketAsyncEventArgs断开后，我们需要断开对应的Socket连接，并释放对应资源
        /// </summary>
        /// <param name="userToken"></param>
        public void CloseClientSocket(AsyncSocketUserToken userToken)
        {
            if (userToken.ConnectSocket == null)
                return;
            string socketInfo = string.Format("Local Address: {0} Remote Address: {1}", userToken.ConnectSocket.LocalEndPoint,
                userToken.ConnectSocket.RemoteEndPoint);
            Program.Logger.InfoFormat("Client connection disconnected. {0}", socketInfo);
            try
            {
                userToken.ConnectSocket.Shutdown(SocketShutdown.Both);
            }
            catch (Exception E) 
            {
                Program.Logger.ErrorFormat("CloseClientSocket Disconnect client {0} error, message: {1}", socketInfo, E.Message);
            }
            userToken.ConnectSocket.Close();
            userToken.ConnectSocket = null; //释放引用，并清理缓存，包括释放协议对象等资源

            m_maxNumberAcceptedClients.Release();
            m_asyncSocketUserTokenPool.Push(userToken);
            m_asyncSocketUserTokenList.Remove(userToken);
        }
    }
}
