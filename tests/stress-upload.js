const { S3Client, PutObjectCommand, DeleteObjectsCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { randomBytes } = require('crypto');

const CONCURRENT = parseInt(process.env.CONCURRENT || '200');
const FILE_SIZE_MB = parseInt(process.env.FILE_SIZE_MB || '5');
const ENDPOINT = process.env.ENDPOINT || 'https://sg-sin-1.linodeobjects.com';
const REGION = process.env.REGION || 'sg-sin-2';
const BUCKET = process.env.INGEST_BUCKET || 'we11-ingest-raw';
const ACCESS_KEY = process.env.NESTJS_ACCESS_KEY;
const SECRET_KEY = process.env.NESTJS_SECRET_KEY;

if (!ACCESS_KEY || !SECRET_KEY) {
  console.error('ERROR: NESTJS_ACCESS_KEY and NESTJS_SECRET_KEY are required');
  process.exit(1);
}

const s3 = new S3Client({
  region: REGION,
  endpoint: ENDPOINT,
  credentials: { accessKeyId: ACCESS_KEY, secretAccessKey: SECRET_KEY},
});

const FILE_SIZE = FILE_SIZE_MB * 1024 * 1024;
const SHARED_BUFFER = randomBytes(FILE_SIZE);
const PREFIX = `stress-test/${Date.now()}`;

async function uploadOne(index) {
  const key = `${PREFIX}/file-${index}.bin`;
  const start = Date.now();

  try {
    await s3.send(new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,
      Body: SHARED_BUFFER, 
      ContentType: 'application/octet-stream',
    }));

    return { index, key, ms: Date.now() - start, ok: true, error: null};
  } catch (error) {
    return { index, key, ms: Date.now() - start, ok: false, error: error.name || error.message };
  }
}

async function cleanup() {
  console.log(`\nCleaning up....`);
  try {
    const listed = await s3.send(new ListObjectsV2Command({
      Bucket: BUCKET, 
      Prefix: PREFIX,
    }));

    if (!listed.Contents || listed.Contents.length === 0) return;

    const batches = [];
    for (let i = 0; i < listed.Contents.length; i += 1000) {
      batches.push(listed.Contents.slice(i, i + 1000));
    }

    for (const batch of batches) {
      await s3.send(new DeleteObjectsCommand({
        Bucket: BUCKET,
        Delete: { Objects: batch.map(o => ({ Key: o.Key })) },
      }));
    }
    console.log(`Deleted ${listed.Contents.length} objects.`);
  } catch (error) {
    console.error(`Cleanup error:`, error.message);
  }
}

function percentile(sorted, p) {
  const idx = Math.ceil(sorted.length * p / 100) - 1;
  return sorted[Math.max(0, idx)];
}

async function main() {
  console.log(`Stress Test: ${CONCURRENT} concurrent uploads x ${FILE_SIZE_MB}MB`);
  console.log(`Bucket: ${BUCKET} | Endpoint: ${ENDPOINT}\n`);

  const wallStart = Date.now();
  const results  = await Promise.allSettled(
    Array.from({ length: CONCURRENT }, (_, i) => uploadOne(i))
  );
  const wallMs = Date.now() - wallStart;

  const outcomes  = results.map(r => r.status === 'fulfilled' ? r.value : { ok: false, ms: 0, error: 'promise_rejected' });
  const successes = outcomes.filter(r => r.ok);
  const failures  = outcomes.filter(r => !r.ok);
  const slowDowns = failures.filter(r => r.error === 'SlowDown' || r.error === '503');

  const latencies = successes.map(r => r.ms).sort((a, b) => a - b);

  console.log('=== RESULTS ===');
  console.log(`Wall time:     ${(wallMs / 1000).toFixed(1)}s`);
  console.log(`Success:       ${successes.length}/${CONCURRENT}`);
  console.log(`Failed:        ${failures.length}/${CONCURRENT}`);
  console.log(`503 SlowDown:  ${slowDowns.length}`);
  console.log(`Error rate:    ${(failures.length / CONCURRENT * 100).toFixed(1)}%`);
  console.log(`PUTs/second:   ${(successes.length / (wallMs / 1000)).toFixed(1)}`);

  if (latencies.length > 0) {
    console.log(`\n=== LATENCY (successful uploads) ===`);
    console.log(`P50: ${percentile(latencies, 50)}ms`);
    console.log(`P95: ${percentile(latencies, 95)}ms`);
    console.log(`P99: ${percentile(latencies, 99)}ms`);
    console.log(`Min: ${latencies[0]}ms`);
    console.log(`Max: ${latencies[latencies.length - 1]}ms`);
  }

  if (failures.length > 0) {
    console.log(`\n=== ERRORS ===`);
    const errorCounts = {};
    failures.forEach(f => { errorCounts[f.error] = (errorCounts[f.error] || 0) + 1; });
    Object.entries(errorCounts).forEach(([error, count]) => {
      console.log(`  ${error}: ${count}`);
    });
  }

  await cleanup();

  const errorRate = failures.length / CONCURRENT;
  if (slowDowns.length > 0 || errorRate > 0.05) {
    console.log('\n❌ FAILED — error rate > 5% or 503 detected');
    process.exit(1);
  }
  console.log('\n✅ PASSED');
}

main();