#include <stdio.h>
int func(void){
	printf("%s\n", __func__);
	return 0;
}
int main(void){
	return func();
}
