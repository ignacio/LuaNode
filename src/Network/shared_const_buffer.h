#pragma once

#include <boost/enable_shared_from_this.hpp>
#include <boost/shared_ptr.hpp>
#include <boost/asio/buffer.hpp>

// A reference-counted non-modifiable buffer class.
class shared_const_buffer
{
public:
	// Construct from a std::string.
	explicit shared_const_buffer(const std::string& data) :
		m_data(new std::vector<char>(data.begin(), data.end())),
		m_buffer(boost::asio::buffer(*m_data))
	{
	}

	// Implement the ConstBufferSequence requirements.
	typedef boost::asio::const_buffer value_type;
	typedef const boost::asio::const_buffer* const_iterator;
	const boost::asio::const_buffer* begin() const { return &m_buffer; }
	const boost::asio::const_buffer* end() const { return &m_buffer + 1; }

private:
	boost::shared_ptr<std::vector<char> > m_data;
	boost::asio::const_buffer m_buffer;
};