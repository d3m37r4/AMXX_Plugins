
/*	
	nVault Array
	    v0.1
	  by bugsy
*/

#if defined _nvault_array_included
	#endinput
#endif
#define _nvault_array_included

#if !defined _nvault_included
	#include <nvault>
#endif

//********************************************************************************************
//   Increase this value if your plugin throws the below error:
//   "Array size too large, you must increase NVAULT_ARRAY_MAXARRAYSIZE in nvault_array.inc"   

const _NVAULT_ARRAY_MAXARRAYSIZE = 500;
//********************************************************************************************

const _NVAULT_ARRAY_CELLSIZE = 5;
const _NVAULT_ARRAY_BUFFERSIZE = ( ( _NVAULT_ARRAY_MAXARRAYSIZE * _NVAULT_ARRAY_CELLSIZE ) + 1 );
const _NVAULT_ARRAY_BYTEMAP = 0b11110000;
const _NVAULT_ARRAY_NULLBYTE = 0b10101010;

/* Description: Set array data in a vault

   Param(s):
   vault - Vault file handle ID that was returned by nvault_open(). Do not pass an nvault utility file ID.
   key[] - Key for data to store.
   array[] - Array of data to store.
   size - Size of array to store (use sizeof(array)).
   
   Return value: 1 on success, 0 on failure.
	
   Comments: None.
*/
stock nvault_set_array( vault , const key[] , const any:array[] , size )
{
	new iArrayPos , iOutputPos , iValue[ 1 ] , szString[ _NVAULT_ARRAY_BUFFERSIZE ];
	
	if ( size > _NVAULT_ARRAY_MAXARRAYSIZE )
		set_fail_state( "[nVault Array] Array size too large, you must increase NVAULT_ARRAY_MAXARRAYSIZE in nvault_array.inc." );
	
	while ( ( iArrayPos < size ) && ( iOutputPos < charsmax( szString ) ) )
	{
		iValue[ 0 ] = array[ iArrayPos++ ];
		
		if ( !( cellmin <= iValue[ 0 ] <= cellmax ) )
			set_fail_state( "[nVault Array] Value exceeds valid long value range." );

		szString[ iOutputPos++ ] = _nvault_array_byte_map( iValue );

		for ( new i = 0 ; i < 4 ; i++ )
			szString[ iOutputPos++ ] = !iValue{ i } ? _NVAULT_ARRAY_NULLBYTE : iValue{ i };
	}
	
	szString[ iOutputPos ] = EOS;
	
	return nvault_set( vault , key , szString );
}

/* Description: Get array data in a vault

   Param(s):
   vault - Vault file handle ID that was returned by nvault_open(). Do not pass an nvault utility file ID.
   key[] - Key for record to retrieve
   array[] - Array to store retrieved data in.
   size - Size of array that data is being retrieved in.
   timestamp - Timestamp of record (passed by reference)
   
   Return value: The number of array elements that were stored in the nvault array record.
	
   Comments: Do not read an nvault record as an array when it was not stored with nvault_set_array()..
*/
stock nvault_get_array( vault , const key[] , any:array[] , size , &timestamp=0 )
{
	new iStringPos , iArrayPos , iValue[ 1 ] , bmByteMap , szString[ _NVAULT_ARRAY_BUFFERSIZE ];
	
	if ( size > _NVAULT_ARRAY_MAXARRAYSIZE )
		set_fail_state( "[nVault Array] Array size too large, you must increase _NVAULT_ARRAY_MAXARRAYSIZE in nvault_array.inc." );
	
	if ( nvault_lookup( vault , key , szString , charsmax( szString ) , timestamp ) )
	{
		while ( szString[ iStringPos ] && ( iStringPos < charsmax( szString ) ) && ( iArrayPos < size ) )
		{
			bmByteMap = szString[ iStringPos++ ];
			
			for ( new i = 0 ; i < 4 ; i++ )
			{
				iValue{ i } = bmByteMap & ( 1 << i ) ? szString[ iStringPos ] : 0;
				iStringPos++;
			}
		
			array[ iArrayPos++ ] = iValue[ 0 ];
		}
	}
	
	return iArrayPos;
}

/* Description: Check if an nvault entry is an array

   Param(s):
   vault - Vault file handle ID that was returned by nvault_open(). Do not pass an nvault utility file ID.
   key[] - Key for record to check
   
   Return value: true / false
*/
stock bool:nvault_isarray( vault , const key[] )
{
	new szData[ _NVAULT_ARRAY_BUFFERSIZE ] , iTS , iDataLen , bool:bRetVal;
	
	if ( nvault_lookup( vault , key , szData , charsmax( szData ) , iTS ) && ( iDataLen = strlen( szData ) ) )
	{
		bRetVal = true;
			
		for ( new i = 0 ; i < iDataLen ; i += _NVAULT_ARRAY_CELLSIZE )
		{
			if ( ( szData[ i ] & _NVAULT_ARRAY_BYTEMAP ) != _NVAULT_ARRAY_BYTEMAP )
			{
				bRetVal = false;
				break;
			}
		}
	}
	
	return bRetVal;
}

/* Description: Get the size of an nvault array

   Param(s):
   vault - Vault file handle ID that was returned by nvault_open(). Do not pass an nvault utility file ID.
   key[] - Key for record to check
   
   Return value:  0 = Record does not exist or is not an nvault array record
		 >0 = How large the array is (in cells)
*/
stock nvault_arraysize( vault , const key[] )
{
	new szData[ _NVAULT_ARRAY_BUFFERSIZE ] , iTS , iDataLen , bool:bIsArray , iRetVal;
	
	if ( nvault_lookup( vault , key , szData , charsmax( szData ) , iTS ) && ( iDataLen = strlen( szData ) ) )
	{
		if ( ( iDataLen < charsmax( szData ) ) && !( iRetVal % _NVAULT_ARRAY_CELLSIZE ) )
		{
			bIsArray = true;
			
			for ( new i = 0 ; i < iDataLen ; i += _NVAULT_ARRAY_CELLSIZE )
			{
				if ( ( szData[ i ] & _NVAULT_ARRAY_BYTEMAP ) != _NVAULT_ARRAY_BYTEMAP )
				{
					bIsArray = false;
					break;
				}
			}
			
			if ( bIsArray == true )
			{
				iRetVal = ( iDataLen / _NVAULT_ARRAY_CELLSIZE );
			}
		}
	}
	
	return iRetVal;
}

stock _nvault_array_byte_map( iValue[ 1 ] )
{
	new iOut[ 1 ] = { _NVAULT_ARRAY_BYTEMAP };

	for ( new i = 0 ; i < 4 ; i++)
		iOut[ 0 ] |= !iValue{ i } ? 0 : ( 1 << i );

	return iOut[ 0 ];
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
