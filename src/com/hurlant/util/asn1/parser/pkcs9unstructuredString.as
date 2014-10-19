package com.hurlant.util.asn1.parser {
	import com.hurlant.util.asn1.type.UniversalStringType;
	
	public function pkcs9unstructuredString(size:int=int.MAX_VALUE,size2:int=0):UniversalStringType {
		return new UniversalStringType(size, size2);
	}
}