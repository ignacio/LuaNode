#include "stdafx.h"
#include "blogger.h"

#include "ClientConnection.h"
//#include "NetUser.h"
//#include "chatsrv.h"

#include <boost/make_shared.hpp>
#include <boost/format.hpp>


int cnx = 0;

CClientConnection::CClientConnection(inConcert::Network::IStreamSocket::Ptr socket, const char* ip) : 
	m_clientIpAddress(ip),
	m_socket(socket)
{
	LogDebug("CClientConnection - new CClientConnection (%p)", this);
	//Register(this);
	++cnx;
}

CClientConnection::~CClientConnection(void)
{
	LogDebug("CClientConnection - delete CClientConnection (%p)", this);
	--cnx;

	/*boost::recursive_mutex::scoped_lock lock( m_userList.GetSyncLock() );
	for(CNetUsers::const_iterator iter = m_userList.begin(), end = m_userList.end(); iter != end; ++iter) {
		const CBString& sID = (*iter)->GetID();
		LogInfo("Removing user:%s on connection destruction", (const char*)sID);
		_Module.m_pServer->LogoutUser(sID);
	}
	m_userList.clear();*/
}

//////////////////////////////////////////////////////////////////////////
/// 
void CClientConnection::Detach() {
	boost::recursive_mutex::scoped_lock lock(m_socketAccessLock);
	m_socket = inConcert::Network::IStreamSocket::Ptr();
}

//////////////////////////////////////////////////////////////////////////
/// 
bool CClientConnection::ProcessCommand(const std::string& command) {
	static const char* sDelimiter = "\r\n";
	static const int nDelimiterLen = lstrlen(sDelimiter);

	LogDebug("CClientConnection::ProcessCommand (%p)", this);
	std::string strCmd = "return ";

	LogDebug(">>>>> %s", command.c_str());
	strCmd += command;

	const char* sResult = NULL;

	if(dostring(strCmd.c_str()) == 0) {
		sResult = lua_tostring(*this, 1);
		lua_settop(*this, 0);
	}
	else {
		sResult = "return -1";
	}

	boost::recursive_mutex::scoped_lock lock(m_socketAccessLock);
	m_socket->Write( shared_const_buffer( std::string(sResult) + "\r\n" ) );
	LogDebug("<<<<< %s", sResult);
	return true;
}
