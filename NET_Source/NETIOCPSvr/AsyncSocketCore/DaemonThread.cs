using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;

namespace NETIOCPSvr
{
    /// <summary>
    /// 在服务端版Socket编程需要处理长时间没有发送数据的Socket，需要在超时多长时间后断开连接，
    /// 我们需要独立一个线程（DaemonThread）来轮询，在执行断开时，
    /// 需要把Socket对象锁定，并调用CloseClientSocket来断开连接
    /// </summary>
    class DaemonThread : Object
    {
        private Thread m_thread;
        private AsyncSocketServer m_asyncSocketServer;

        public DaemonThread(AsyncSocketServer asyncSocketServer)
        {
            m_asyncSocketServer = asyncSocketServer;
            m_thread = new Thread(DaemonThreadStart);
            m_thread.Start();
        }

        public void DaemonThreadStart()
        {
            while (m_thread.IsAlive)
            {
                AsyncSocketUserToken[] userTokenArray = null;
                m_asyncSocketServer.AsyncSocketUserTokenList.CopyList(ref userTokenArray);
                for (int i = 0; i < userTokenArray.Length; i++)
                {
                    if (!m_thread.IsAlive)
                        break;
                    try
                    {                       
                        if ((DateTime.Now - userTokenArray[i].ActiveDateTime).TotalMilliseconds > m_asyncSocketServer.SocketTimeOutMS)
                        {//超时Socket断开  Milliseconds -> TotalMilliseconds
                            lock (userTokenArray[i])
                            {
                                m_asyncSocketServer.CloseClientSocket(userTokenArray[i]);
                            }
                        }
                    }                    
                    catch (Exception E)
                    {
                        Program.Logger.ErrorFormat("Daemon thread check timeout socket error, message: {0}", E.Message);
                        Program.Logger.Error(E.StackTrace);
                    }
                }

                for (int i = 0; i < 60 * 1000 / 10; i++) 
                {//每分钟检测一次
                    if (!m_thread.IsAlive)
                        break;
                    Thread.Sleep(10);
                }
            }
        }

        public void Close()
        {
            m_thread.Abort();
            m_thread.Join();
        }
    }
}
