from pathlib import Path
import subprocess,os
base=Path('/tmp/wide-improve');ghdl='/tmp/livt-ghdl/root/usr/bin/ghdl-mcode'
env=dict(os.environ);env['GHDL_PREFIX']='/tmp/livt-ghdl/root/usr/lib/ghdl/mcode/vhdl'
for project,entities in [('livt-ml',['livt_ml_tests_fixedtransformerkernelstest','livt_ml_tests_embedding_fixedtokenembeddingtest']),('app-numeric',['livt_onnx_flant5_tests_flant5numerictest','livt_onnx_flant5_tests_flant5fixedpointtest','livt_onnx_flant5_tests_flant5matrixtest','livt_onnx_flant5_tests_flant5nonlineartest','livt_onnx_flant5_tests_flant5tablearithmetictest'])]:
 work=base/('final-rtl-'+project);work.mkdir(exist_ok=True)
 files=[str(p) for p in (base/project/'out/debug').rglob('*.vhd') if p.name!='WideArithmeticPrimitive.vhd']
 files.append('/home/vagrant/git/livt/livt-math/src/arithmetic/WideArithmeticPrimitive.vhd')
 def run(cmd,log):
  with (work/log).open('w') as out:subprocess.run([ghdl,*cmd],cwd=work,env=env,stdout=out,stderr=subprocess.STDOUT,check=True,timeout=300)
 run(['-i','--std=08',*files],'import.log')
 for entity in entities:
  run(['-m','--std=08',entity],entity+'-elaborate.log')
  for reset in ['false','true']:
   run(['-r','--std=08',entity,'-gLVT_RESET_ASYNC='+reset,'--assert-level=error'],entity+'-'+reset+'.log')
 print('PASS',project,'with final native worker in both reset modes',flush=True)
