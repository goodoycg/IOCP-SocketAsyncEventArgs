using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net.Sockets;

namespace NETIOCPSvr
{
    /// <summary>
    /// 高吞吐量
    /// </summary>
    class ThroughputSocketProtocol : BaseSocketProtocol
    {
        public ThroughputSocketProtocol(AsyncSocketServer asyncSocketServer, AsyncSocketUserToken asyncSocketUserToken)
            : base(asyncSocketServer, asyncSocketUserToken)
        {
            m_socketFlag = "Throughput";
        }        
        public override void Close()
        {
            base.Close();
        }
        /// <summary>
        /// 
        /// </summary>
        /// <param name="buffer"></param>
        /// <param name="offset"></param>
        /// <param name="count"></param>
        /// <returns></returns>
        public override bool ProcessCommand(byte[] buffer, int offset, int count) //
        {
            ThroughputSocketCommand command = StrToCommand(m_incomingDataParser.Command);
            m_outgoingDataAssembler.Clear();
            m_outgoingDataAssembler.AddResponse();
            m_outgoingDataAssembler.AddCommand(m_incomingDataParser.Command);
            if (command == ThroughputSocketCommand.CyclePacket)
                return DoCyclePacket(buffer, offset, count);
            else
            {
                Program.Logger.Error("Unknow command: " + m_incomingDataParser.Command);
                return false;
            }
        }

        public ThroughputSocketCommand StrToCommand(string command)
        {
            if (command.Equals(ProtocolKey.CyclePacket, StringComparison.CurrentCultureIgnoreCase))
                return ThroughputSocketCommand.CyclePacket;
            else
                return ThroughputSocketCommand.None;
        }

        public bool DoCyclePacket(byte[] buffer, int offset, int count)
        {
            int cycleCount = 0;
            if (m_incomingDataParser.GetValue(ProtocolKey.Count, ref cycleCount))
            {
                m_outgoingDataAssembler.AddSuccess();
                cycleCount = cycleCount + 1;
                m_outgoingDataAssembler.AddValue(ProtocolKey.Count, cycleCount);
            }
            else
                m_outgoingDataAssembler.AddFailure(ProtocolCode.ParameterError, "");
            return DoSendResult(buffer, offset, count);
        }
    }
}
